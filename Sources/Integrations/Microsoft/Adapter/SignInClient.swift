import Foundation
import Hub

struct SignInClient: SignInPort {
    let oauth: OAuthClient
    let openBrowser: @Sendable (URL) async -> Bool
    let makeRedirect: @Sendable () -> any RedirectPort
    let clock: @Sendable () -> Date

    func signIn(_ inlet: Inlet, input: [Field.ID: String]) async throws -> Grant {
        let server = makeRedirect()
        do {
            let redirectURI = try await server.start()
            let params = try oauth.authorization(redirectURI: redirectURI, loginHint: input[Input.expectedAccountKey])
            guard await openBrowser(params.url) else { throw SignInFailure.browserFailed }
            let callback = try await server.awaitRedirect()
            server.stop()
            if let fault = oauth.fault(in: callback, expectedState: params.state) { throw MicrosoftFailure.api(fault) }
            guard let code = oauth.code(from: callback, expectedState: params.state) else {
                throw SignInFailure.redirectStateMismatch
            }
            let token = try await oauth.exchange(code: code, verifier: params.pkce.verifier, redirectURI: redirectURI)
            guard let identity = token.idToken.flatMap(IdentityParser.parse) else { throw MicrosoftFailure.identityMissing }
            return TokenState(token: token, identity: identity, previousRefresh: nil, now: clock()).grant
        } catch {
            server.stop()
            throw error
        }
    }

    func renew(_ grant: Grant) async throws -> Grant {
        let state = try TokenState(grant: grant)
        guard let refreshToken = state.refreshToken else { throw SignInFailure.refreshUnavailable }
        let token = try await oauth.refresh(refreshToken: refreshToken)
        return TokenState(token: token, identity: state.identity, previousRefresh: refreshToken, now: clock()).grant
    }

    func signOut(_ inlet: Inlet) async throws {}
}
