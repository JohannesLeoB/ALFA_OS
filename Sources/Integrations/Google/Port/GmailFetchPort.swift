import Foundation

protocol GmailFetchPort: Sendable {
    func listMessages(query: String, maxResults: Int, pageToken: String?) async throws -> GmailPage
    func listIDs(query: String, maxResults: Int, pageToken: String?) async throws -> GmailIDs
    func fetchMetadata(ids: [String]) async throws -> [GmailMessage]
    func fetchLabels(ids: [String]) async throws -> [String: [String]]
    func labelChanges(since historyID: String) async throws -> GmailChanges
    func currentHistoryID() async throws -> String
    func fetchMailBody(messageID: String) async throws -> GmailMailBody
    func fetchBody(messageID: String) async throws -> String
    func fetchRaw(messageID: String) async throws -> Data
    func fetchThread(threadID: String, maxMessages: Int) async throws -> [GmailMessage]
    func downloadAttachment(messageID: String, attachmentID: String) async throws -> Data
}

extension GmailFetchPort {
    func searchMessages(query: String, maxResults: Int) async throws -> [GmailMessage] {
        try await listMessages(query: query, maxResults: maxResults, pageToken: nil).messages
    }
}
