import Foundation

protocol AccessTokenPort: Sendable {
    func validAccessToken() async throws -> String
}

protocol TokenRefreshPort: Sendable {
    func refresh(refreshToken: String) async throws -> OAuthToken
}

public protocol RedirectPort: Sendable {
    func start() async throws -> String
    func awaitRedirect() async throws -> URL
    func stop()
}
