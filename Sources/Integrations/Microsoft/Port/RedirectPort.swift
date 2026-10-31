import Foundation

protocol RedirectPort: Sendable {
    func start() async throws -> String
    func awaitRedirect() async throws -> URL
    func stop()
}

protocol TokenRefreshPort: Sendable {
    func refresh(refreshToken: String) async throws -> OAuthToken
}
