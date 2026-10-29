import Mail

protocol GmailWritePort: Sendable {
    func createDraft(_ draft: Draft) async throws -> SavedDraft
    func sendMessage(_ draft: Draft) async throws
}
