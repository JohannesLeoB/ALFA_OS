import Mail

protocol GmailWritePort: Sendable {
    func createDraft(_ draft: Draft) async throws -> String
    func sendMessage(_ draft: Draft) async throws
}
