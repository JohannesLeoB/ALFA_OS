public protocol ContactFeedPort: Sendable {
    func people() async throws -> [ContactPerson]
}
