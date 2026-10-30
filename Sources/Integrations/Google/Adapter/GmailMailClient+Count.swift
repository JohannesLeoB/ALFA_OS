import Mail

extension GmailMailClient: UnseenCountPort {
    func unseen(folderID: String) async throws -> FolderCount? {
        guard folderID != Self.allMail else { return nil }
        return try await gmail.labelCount(id: folderID)
    }
}
