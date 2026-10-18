import Foundation
import AlfaServices

public struct GoogleSignIn: SignInPort {
    let config: GoogleClientConfig
    let session: URLSession
    let scopes: [GoogleOAuthScope]
    let openBrowser: @Sendable (URL) async -> Bool
    let makeServer: @Sendable () -> GoogleOAuthLoopbackRedirectServer
    let clock: @Sendable () -> Date

    public init(
        config: GoogleClientConfig,
        session: URLSession = .shared,
        scopes: [GoogleOAuthScope] = GoogleOAuthScope.standardScopes,
        openBrowser: @escaping @Sendable (URL) async -> Bool,
        makeServer: @escaping @Sendable () -> GoogleOAuthLoopbackRedirectServer = { GoogleOAuthLoopbackRedirectServer() },
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.config = config
        self.session = session
        self.scopes = scopes
        self.openBrowser = openBrowser
        self.makeServer = makeServer
        self.clock = clock
    }

    public func signIn(_ inlet: Inlet, input: [Field.ID: String]) async throws -> Grant {
        let server = makeServer()
        do {
            let redirectURI = try await server.start()
            let pkce = GoogleOAuthPKCEService(clientID: config.clientID,
                                              clientSecret: config.clientSecret.isEmpty ? nil : config.clientSecret,
                                              redirectURI: redirectURI)
            guard let request = pkce.buildAuthorizationRequest(scopes: scopes) else {
                throw GoogleOAuthError.invalidEndpoint
            }
            guard await openBrowser(request.url) else { throw GoogleProviderError.browserFailed }
            let callback = try await server.awaitRedirect()
            server.stop()
            guard let redirect = pkce.parseRedirect(callback, expectedState: request.state) else {
                throw GoogleOAuthError.redirectStateMismatch
            }
            let response = try await pkce.exchangeCodeForToken(code: redirect.code,
                                                               codeVerifier: request.pkce.verifier, session: session)
            return GoogleTokenState(response: response, previousRefresh: nil, now: clock()).grant
        } catch {
            server.stop()
            throw error
        }
    }

    public func renew(_ grant: Grant) async throws -> Grant {
        let state = try GoogleTokenState(grant: grant)
        guard let refreshToken = state.refreshToken else { throw GoogleProviderError.refreshUnavailable }
        let response = try await GoogleTokenRefreshService(session: session)
            .refresh(refreshToken: refreshToken, clientID: config.clientID, clientSecret: config.clientSecret)
        return GoogleTokenState(response: response, previousRefresh: refreshToken, now: clock()).grant
    }

    public func signOut(_ inlet: Inlet) async throws {}
}
