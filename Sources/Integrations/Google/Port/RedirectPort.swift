import Foundation

public protocol RedirectPort: Sendable {
    func start() async throws -> String
    func awaitRedirect() async throws -> URL
    func stop()
}
