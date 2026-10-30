import Foundation

public protocol MailTransportPort: Sendable {
    func listFolders() async throws -> [Folder]
    func listMessages(folderID: String, query: String?, pageToken: String?, maxResults: Int) async throws -> MessagePage
    func fetchBody(messageID: String) async throws -> MessageBody
    func send(_ draft: Draft) async throws
    func setFlags(messageID: String, add: Set<Flag>, remove: Set<Flag>) async throws
    func archive(messageID: String, folderID: String?) async throws
    func move(messageID: String, toFolderID: String) async throws
    func trash(messageID: String, folderID: String?) async throws
    func markSpam(messageID: String, folderID: String?) async throws
    func fetchAttachment(messageID: String, attachmentID: String) async throws -> Data
    func fetchThread(messageID: String, threadID: String) async throws -> [MessageSummary]
    func saveDraft(_ draft: Draft, replacing draftID: String?, into folderID: String?) async throws -> SavedDraft
    func fetchDraft(messageID: String) async throws -> StoredDraft
    func deleteDraft(id: String) async throws
    func sendDraft(id: String) async throws
    func wasSent(messageID: String, in folderID: String?) async throws -> Bool
}
