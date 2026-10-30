protocol TokenRefreshPort: Sendable {
    func refresh(refreshToken: String) async throws -> OAuthToken
}
