import Foundation
import Hub

struct SignInClient: SignInPort {
    let oauth: OAuthClient
    let openBrowser: @Sendable (URL) async -> Bool
    let makeRedirect: @Sendable () -> any RedirectPort
    let clock: @Sendable () -> Date

    init(oauth: OAuthClient,
         openBrowser: @escaping @Sendable (URL) async -> Bool,
         makeRedirect: @escaping @Sendable () -> any RedirectPort,
         clock: @escaping @Sendable () -> Date) {
        self.oauth = oauth
        self.openBrowser = openBrowser
        self.makeRedirect = makeRedirect
        self.clock = clock
    }

    func signIn(_ inlet: Inlet, input: [Field.ID: String]) async throws -> Grant {
        let server = makeRedirect()
        do {
            let redirectURI = try await server.start()
            let params = try oauth.authorization(
                scopes: ScopeEngine.scopes(for: inlet.capabilities), redirectURI: redirectURI, loginHint: input[Input.expectedAccountKey])
            guard await openBrowser(params.url) else { throw SignInFailure.browserFailed }
            let callback = try await server.awaitRedirect()
            server.stop()
            guard let code = oauth.code(from: callback, expectedState: params.state) else {
                throw SignInFailure.redirectStateMismatch
            }
            let token = try await oauth.exchange(code: code, verifier: params.pkce.verifier, redirectURI: redirectURI)
            return StoredToken(token: token, previousRefresh: nil, now: clock()).grant
        } catch {
            server.stop()
            throw error
        }
    }

    func renew(_ grant: Grant) async throws -> Grant {
        let state = try StoredToken(grant: grant)
        guard let refreshToken = state.refreshToken else { throw SignInFailure.refreshUnavailable }
        let token = try await oauth.refresh(refreshToken: refreshToken)
        return StoredToken(token: token, previousRefresh: refreshToken, now: clock()).grant
    }

    func signOut(_ inlet: Inlet) async throws {}

    func revoke(_ grant: Grant) async throws {
        let state = try StoredToken(grant: grant)
        try await oauth.revoke(token: state.refreshToken ?? state.accessToken)
    }
}
