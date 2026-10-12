import Foundation

public protocol GoogleAccessTokenProviding: Sendable {
    func validAccessToken() async throws -> String
}

public struct GoogleAccessTokenProvider: GoogleAccessTokenProviding {
    private let tokenStore: GoogleTokenStoring
    private let refreshing: GoogleTokenRefreshing

    public init(
        tokenStore: GoogleTokenStoring = KeychainGoogleTokenStore(),
        refreshing: GoogleTokenRefreshing = GoogleTokenRefreshService()
    ) {
        self.tokenStore = tokenStore
        self.refreshing = refreshing
    }

    public func validAccessToken() async throws -> String {
        guard let tokens = try? tokenStore.load() else {
            throw GoogleOAuthError.notConnected
        }
        guard tokens.isExpired else {
            return tokens.accessToken
        }
        guard let refreshToken = tokens.refreshToken,
              let clientID = try? tokenStore.loadClientID() else {
            throw GoogleOAuthError.refreshUnavailable
        }

        let clientSecret = try? tokenStore.loadClientSecret()
        let response = try await refreshing.refresh(refreshToken: refreshToken, clientID: clientID, clientSecret: clientSecret ?? nil)
        let refreshed = GoogleTokens(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken ?? refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn ?? 3600))
        )
        try tokenStore.store(refreshed)
        return refreshed.accessToken
    }
}
