import Mail

protocol GmailDraftPort: Sendable {
    func getDraft(id: String) async throws -> Draft
    func updateDraft(id: String, draft: Draft) async throws -> String
    func sendDraft(id: String) async throws
    func deleteDraft(id: String) async throws
    func listDraftIDMap() async throws -> [String: String]
}
