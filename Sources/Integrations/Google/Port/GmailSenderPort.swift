import Mail

protocol GmailSenderPort: Sendable {
    func listSendAs() async throws -> [Participant]
}
