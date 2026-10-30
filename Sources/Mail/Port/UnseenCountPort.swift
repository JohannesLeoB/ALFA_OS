public protocol UnseenCountPort: Sendable {
    func unseen(folderID: String) async throws -> FolderCount?
}
