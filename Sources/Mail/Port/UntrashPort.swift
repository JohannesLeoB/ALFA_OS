public protocol UntrashPort: Sendable {
    func untrash(messageID: String) async throws
}
