import Foundation
import AlfaServices

public struct GoogleProbe: ProbePort {
    let config: GoogleClientConfig
    let session: URLSession
    let clock: @Sendable () -> Date

    public init(config: GoogleClientConfig, session: URLSession = .shared, clock: @escaping @Sendable () -> Date = { Date() }) {
        self.config = config
        self.session = session
        self.clock = clock
    }

    public func probe(_ inlet: Inlet, _ grant: Grant) async throws -> ProbeResult {
        let state: GoogleTokenState
        do {
            state = try GoogleTokenState(grant: grant)
        } catch {
            return ProbeResult(account: inlet.id, rejection: Hint(text: "hint.google.grant", detail: String(describing: error)))
        }
        let tokens = GoogleGrantTokenProvider(state: state, config: config,
                                              refresher: GoogleTokenRefreshService(session: session), clock: clock)
        let token: String
        do {
            token = try await tokens.validAccessToken()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return ProbeResult(account: inlet.id, rejection: Self.hint("hint.google.token", error))
        }
        let email: String
        do {
            email = try await GoogleUserInfoClient(httpClient: session).fetchUserInfo(accessToken: token).email
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return ProbeResult(account: inlet.id, rejection: Self.hint("hint.google.userinfo", error))
        }
        do {
            _ = try await GoogleGmailClient(tokenProvider: tokens, session: session).listLabels()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return ProbeResult(account: email, rejection: Self.hint("hint.google.labels", error))
        }
        return ProbeResult(account: email)
    }

    static func hint(_ text: String, _ error: Error) -> Hint {
        let classification = GoogleFailure.classify(error)
        return Hint(text: text, detail: detail(of: error), kind: classification.kind, original: classification.original)
    }

    static func detail(of error: Error) -> String {
        let classification = GoogleFailure.classify(error)
        switch error {
        case GoogleOAuthError.api, GoogleGmailError.api, GoogleOAuthError.httpError, GoogleGmailError.httpError,
             GoogleProviderError.http:
            return classification.detail ?? "HTTP \(classification.original.status ?? 0)"
        case GoogleGmailError.notConnected, GoogleOAuthError.notConnected:
            return "HTTP 401"
        default:
            return String(describing: error)
        }
    }
}
