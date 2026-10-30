extension IMAPSMTPClient: UnseenCountPort {
    func unseen(folderID: String) async throws -> FolderCount? {
        try await withIncoming { session in try await session.status(folderID) }
    }
}
