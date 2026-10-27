protocol AccessTokenPort: Sendable {
    func validAccessToken() async throws -> String
}
