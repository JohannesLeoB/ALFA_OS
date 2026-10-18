import Foundation
import Observation
import AlfaKit
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@MainActor
@Observable
public final class GoogleAuthService {
    public private(set) var status: GoogleConnectionStatus

    public private(set) var currentUser: GoogleUserInfo?

    private let tokenStore: GoogleTokenStoring
    private let redirectServer: GoogleOAuthLoopbackRedirectServer
    private let scopes: [GoogleOAuthScope]
    private let userInfoClient: GoogleUserInfoFetching

    public var onLoginComplete: (@MainActor () async -> Void)?

    public init(
        tokenStore: GoogleTokenStoring = KeychainGoogleTokenStore(),
        redirectServer: GoogleOAuthLoopbackRedirectServer = .shared,
        scopes: [GoogleOAuthScope] = GoogleOAuthScope.standardScopes,
        userInfoClient: GoogleUserInfoFetching = GoogleUserInfoClient()
    ) {
        self.tokenStore = tokenStore
        self.redirectServer = redirectServer
        self.scopes = scopes
        self.userInfoClient = userInfoClient
        self.status = (try? tokenStore.load()) != nil ? .connected : .disconnected
        self.currentUser = try? tokenStore.loadUserInfo()
    }

    public func storedClientID() throws -> String? {
        try tokenStore.loadClientID()
    }

    public func storedClientSecret() throws -> String? {
        try tokenStore.loadClientSecret()
    }

    public func storeClientConfig(clientID: String, clientSecret: String?) throws {
        let trimmedID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedID.isEmpty == false else { return }
        try tokenStore.storeClientID(trimmedID)
        if let clientSecret {
            let trimmedSecret = clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedSecret.isEmpty == false { try tokenStore.storeClientSecret(trimmedSecret) }
        }
    }

    public func startAuthorization(clientID: String, clientSecret: String = "") async throws {
        let trimmedClientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedClientSecret = clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedClientID.isEmpty == false else {
            status = .error("Client-ID fehlt")
            throw GoogleOAuthError.missingClientID
        }

        status = .connecting
        do {
            try tokenStore.storeClientID(trimmedClientID)
            if trimmedClientSecret.isEmpty == false {
                try tokenStore.storeClientSecret(trimmedClientSecret)
            }

            let redirectURI = try await redirectServer.start()
            let pkceService = GoogleOAuthPKCEService(
                clientID: trimmedClientID,
                clientSecret: trimmedClientSecret.isEmpty ? nil : trimmedClientSecret,
                redirectURI: redirectURI
            )
            guard let request = pkceService.buildAuthorizationRequest(scopes: scopes) else {
                throw GoogleOAuthError.invalidEndpoint
            }

            #if canImport(AppKit)
            NSWorkspace.shared.open(request.url)
            #elseif canImport(UIKit)
            await UIApplication.shared.open(request.url)
            #endif

            let callbackURL = try await redirectServer.awaitRedirect()
            redirectServer.stop()

            guard let redirect = pkceService.parseRedirect(callbackURL, expectedState: request.state) else {
                throw GoogleOAuthError.redirectStateMismatch
            }

            let response = try await pkceService.exchangeCodeForToken(
                code: redirect.code,
                codeVerifier: request.pkce.verifier
            )
            let tokens = GoogleTokens(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn ?? 3600))
            )
            try tokenStore.store(tokens)

            do {
                let info = try await userInfoClient.fetchUserInfo(accessToken: response.accessToken)
                try tokenStore.storeUserInfo(info)
                currentUser = info
            } catch {}
            status = .connected

            await onLoginComplete?()
        } catch {
            redirectServer.stop()
            status = .error(String(describing: error))
            throw error
        }
    }

    public func disconnect() throws {
        try tokenStore.clear()
        currentUser = nil
        status = .disconnected
    }

    public func refreshUserInfoIfNeeded() async {
        guard status == .connected, currentUser == nil else { return }
        do {
            let token = try await GoogleAccessTokenProvider(tokenStore: tokenStore).validAccessToken()
            let info = try await userInfoClient.fetchUserInfo(accessToken: token)
            try tokenStore.storeUserInfo(info)
            currentUser = info
        } catch {}
    }
}
