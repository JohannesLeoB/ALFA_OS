import Foundation
import Hub

struct ProbeClient: ProbePort {
    static let grantKey = "hint.google.grant"
    static let tokenKey = "hint.google.token"
    static let userInfoKey = "hint.google.userinfo"
    static let labelsKey = "hint.google.labels"
    static let unauthorizedDetail = "HTTP 401"

    let oauth: OAuthClient
    let clock: @Sendable () -> Date
    let policy: RequestPolicy

    func probe(_ inlet: Inlet, _ grant: Grant) async throws -> ProbeResult {
        let state: StoredToken
        do {
            state = try StoredToken(grant: grant)
        } catch {
            return ProbeResult(account: inlet.id, rejection: Hint(text: Self.grantKey, detail: String(describing: error)))
        }
        let tokens = AccessTokenClient(state: state, refresher: oauth, clock: clock)
        let token: String
        do {
            token = try await tokens.validAccessToken()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return ProbeResult(account: inlet.id, rejection: Self.hint(Self.tokenKey, error))
        }
        let email: String
        do {
            email = try await UserInfoClient(http: oauth.http).fetchUserInfo(accessToken: token).email
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return ProbeResult(account: inlet.id, rejection: Self.hint(Self.userInfoKey, error))
        }
        let gmail = GmailClient(requests: RequestClient(http: oauth.http, tokens: tokens, product: .gmail), policy: policy)
        do {
            _ = try await gmail.listLabels()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return ProbeResult(account: email, rejection: Self.hint(Self.labelsKey, error))
        }
        return ProbeResult(account: email)
    }

    static func hint(_ text: String, _ error: any Error) -> Hint {
        let classification = FailureEngine.classify(error)
        return Hint(text: text, detail: detail(of: error, classification), kind: classification.kind,
                    original: classification.original)
    }

    private static func detail(of error: any Error, _ classification: Classification) -> String {
        switch error {
        case GoogleFailure.api: classification.detail ?? "HTTP \(classification.original.status ?? 0)"
        case GoogleFailure.notConnected: unauthorizedDetail
        default: String(describing: error)
        }
    }
}
