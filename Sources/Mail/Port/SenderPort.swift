public protocol SenderPort: Sendable {
    func senders() async throws -> [Participant]
}
