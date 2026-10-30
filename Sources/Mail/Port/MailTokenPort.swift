public protocol MailTokenPort: Sendable {
    func accessToken() async throws -> String
}
