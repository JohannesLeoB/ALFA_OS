import Foundation
import MykilosServices

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
        } catch {
            return ProbeResult(account: inlet.id, rejection: Self.hint("hint.google.token", error))
        }
        let email: String
        do {
            email = try await GoogleUserInfoClient(httpClient: session).fetchUserInfo(accessToken: token).email
        } catch {
            return ProbeResult(account: inlet.id, rejection: Self.hint("hint.google.userinfo", error))
        }
        do {
            _ = try await GoogleGmailClient(tokenProvider: tokens, session: session).listLabels()
        } catch {
            return ProbeResult(account: email, rejection: Self.hint("hint.google.labels", error))
        }
        return ProbeResult(account: email)
    }

    static func hint(_ text: String, _ error: Error) -> Hint {
        Hint(text: text, detail: detail(of: error))
    }

    static func detail(of error: Error) -> String {
        switch error {
        case GoogleOAuthError.httpError(let code), GoogleGmailError.httpError(let code),
             GoogleProviderError.http(let code):
            return "HTTP \(code)"
        case GoogleGmailError.notConnected, GoogleOAuthError.notConnected:
            return "HTTP 401"
        default:
            return String(describing: error)
        }
    }
}
