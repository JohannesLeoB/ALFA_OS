import Foundation
import Mail

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

protocol GmailLabelPort: Sendable {
    func modifyLabels(messageID: String, add: [String], remove: [String]) async throws
    func trashMessage(messageID: String) async throws
    func untrashMessage(messageID: String) async throws
    func listLabels() async throws -> [GmailLabel]
    func labelCount(id: String) async throws -> FolderCount?
}

extension GmailLabelPort {
    func markSpam(messageID: String) async throws {
        try await modifyLabels(messageID: messageID, add: [GmailSystemLabel.spam], remove: [GmailSystemLabel.inbox])
    }
}

protocol GmailDraftPort: Sendable {
    func getDraft(id: String) async throws -> Draft
    func updateDraft(id: String, draft: Draft) async throws -> SavedDraft
    func sendDraft(id: String) async throws
    func deleteDraft(id: String) async throws
    func listDraftIDMap() async throws -> [String: String]
}

protocol GmailSenderPort: Sendable {
    func listSendAs() async throws -> [Participant]
}

protocol GmailWritePort: Sendable {
    func createDraft(_ draft: Draft) async throws -> SavedDraft
    func sendMessage(_ draft: Draft) async throws
}

protocol DriveFetchPort: Sendable {
    func listFolder(folderID: String) async throws -> [DriveFile]
    func listDrives() async throws -> [DriveFile]
    func fileName(of fileID: String) async throws -> String
    func downloadContent(fileID: String) async throws -> Data
    func exportFile(fileID: String, exportMimeType: String) async throws -> Data
    func findOrCreateSubfolder(parentID: String, name: String) async throws -> String
    func uploadFile(name: String, mimeType: String, data: Data, parentFolderID: String) async throws -> DriveFile
}

protocol CalendarFetchPort: Sendable {
    func listCalendars() async throws -> [EventCalendar]
    func upcomingEvents(calendarID: String?, query: String?, withinDays: Int) async throws -> [CalendarEvent]
}

protocol ContactsFetchPort: Sendable {
    func searchContacts(query: String?) async throws -> [Contact]
    func allContacts() async throws -> [Contact]
}
