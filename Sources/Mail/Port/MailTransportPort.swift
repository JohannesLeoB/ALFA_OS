import Foundation
import Hub

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

public protocol GmailPort: MailTransportPort {}

protocol SentCopyPort: Sendable {
    var filesSentCopy: Bool { get }
    func fileSent(_ draft: Draft, into folderID: String?) async throws
}

public protocol ServerCopyPort: Sendable {
    func expire(_ policy: ServerCopy, now: Date) async throws
}

public protocol SendLimitPort: Sendable {
    func sendLimit() async throws -> Int?
}

public protocol SenderPort: Sendable {
    func senders() async throws -> [Participant]
}

public protocol UntrashPort: Sendable {
    func untrash(messageID: String) async throws
}

protocol PurgePort: Sendable {
    func supportsPurge() async throws -> Bool
    func purge(messageID: String) async throws
}

public protocol SourcePort: Sendable {
    var offersSource: Bool { get }
    func fetchSource(messageID: String) async throws -> Data
}

public protocol LabelPort: Sendable {
    var usesLabels: Bool { get }
}

public protocol InboxOnlyPort: Sendable {
    var inboxOnly: Bool { get }
}
