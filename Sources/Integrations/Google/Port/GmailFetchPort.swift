import Foundation

protocol GmailFetchPort: Sendable {
    func listMessages(query: String, maxResults: Int, pageToken: String?) async throws -> GmailPage
    func fetchMailBody(messageID: String) async throws -> GmailMailBody
    func fetchBody(messageID: String) async throws -> String
    func fetchThread(threadID: String, maxMessages: Int) async throws -> [GmailMessage]
    func downloadAttachment(messageID: String, attachmentID: String) async throws -> Data
}

extension GmailFetchPort {
    func searchMessages(query: String, maxResults: Int) async throws -> [GmailMessage] {
        try await listMessages(query: query, maxResults: maxResults, pageToken: nil).messages
    }
}
