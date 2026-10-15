import Foundation
import MykilosKit

public struct GmailMailTransport: MailTransport {
    private let client: GoogleGmailClient

    public init(client: GoogleGmailClient = GmailAccess.client()) {
        self.client = client
    }

    static let allMail = "ALL"
    static let threadLimit = 20

    static let systemFolders: [MailFolder] = [
        MailFolder(id: GmailSystemLabel.inbox, name: GmailSystemLabel.inbox, role: .inbox),
        MailFolder(id: GmailSystemLabel.starred, name: GmailSystemLabel.starred, role: .starred),
        MailFolder(id: GmailSystemLabel.sent, name: GmailSystemLabel.sent, role: .sent),
        MailFolder(id: GmailSystemLabel.draft, name: GmailSystemLabel.draft, role: .drafts),
        MailFolder(id: allMail, name: allMail, role: .all),
        MailFolder(id: GmailSystemLabel.spam, name: GmailSystemLabel.spam, role: .spam),
        MailFolder(id: GmailSystemLabel.trash, name: GmailSystemLabel.trash, role: .trash),
    ]

    public func listFolders() async throws -> [MailFolder] {
        let labels = try await client.listLabels().map { MailFolder(id: $0.id, name: $0.name, role: .other) }
        return Self.systemFolders + labels
    }

    public func listMessages(folderID: String, query: String?, pageToken: String?, maxResults: Int) async throws -> MailMessagePage {
        let scope = try await labelQuery(folderID)
        let combined = [scope, query].compactMap { $0 }.filter { $0.isEmpty == false }.joined(separator: " ")
        let page = try await client.listMessages(query: combined, maxResults: maxResults, pageToken: pageToken)
        return MailMessagePage(messages: page.messages.map(Self.summary), nextPageToken: page.nextPageToken)
    }

    public func fetchBody(messageID: String) async throws -> MailMessageBody {
        let body = try await client.fetchMailBody(messageID: messageID)
        let attachments = body.attachments.map {
            MailAttachmentInfo(id: $0.attachmentID, filename: $0.filename, mimeType: $0.mimeType, sizeBytes: $0.sizeBytes)
        }
        return MailMessageBody(text: body.text, html: body.html, inlineImages: body.inlineImages, attachments: attachments)
    }

    public func archive(messageID: String) async throws {
        try await client.modifyLabels(messageID: messageID, add: [], remove: [GmailSystemLabel.inbox])
    }

    public func move(messageID: String, toFolderID: String) async throws {
        switch toFolderID {
        case GmailSystemLabel.trash:
            try await client.trashMessage(messageID: messageID)
        case GmailSystemLabel.spam:
            try await client.markSpam(messageID: messageID)
        case Self.allMail:
            try await archive(messageID: messageID)
        case GmailSystemLabel.inbox:
            try await client.modifyLabels(messageID: messageID, add: [GmailSystemLabel.inbox], remove: [])
        case GmailSystemLabel.starred, GmailSystemLabel.sent, GmailSystemLabel.draft:
            throw MailTransportError.folderNotFound(toFolderID)
        default:
            try await client.modifyLabels(messageID: messageID, add: [toFolderID], remove: [GmailSystemLabel.inbox])
        }
    }

    public func trash(messageID: String) async throws {
        try await client.trashMessage(messageID: messageID)
    }

    public func markSpam(messageID: String) async throws {
        try await client.markSpam(messageID: messageID)
    }

    public func fetchAttachment(messageID: String, attachmentID: String) async throws -> Data {
        try await client.downloadAttachment(messageID: messageID, attachmentID: attachmentID)
    }

    public func fetchThread(messageID: String, threadID: String) async throws -> [MailMessageSummary] {
        let messages = try await client.fetchThread(threadID: threadID, maxMessages: Self.threadLimit)
        return messages.map(Self.summary)
    }

    public func saveDraft(_ draft: EmailDraft, replacing draftID: String?) async throws -> String {
        if let draftID { return try await client.updateDraft(id: draftID, draft: draft) }
        return try await client.createDraft(draft)
    }

    public func fetchDraft(messageID: String) async throws -> MailStoredDraft {
        let map = try await client.listDraftIDMap()
        guard let draftID = map[messageID] else { throw MailTransportError.messageNotFound(messageID) }
        return MailStoredDraft(id: draftID, draft: try await client.getDraft(id: draftID))
    }

    public func deleteDraft(id: String) async throws {
        try await client.deleteDraft(id: id)
    }

    public func sendDraft(id: String) async throws {
        try await client.sendDraft(id: id)
    }

    public func send(_ draft: EmailDraft) async throws {
        try await client.sendMessage(draft)
    }

    public func setFlags(messageID: String, add: Set<MailFlag>, remove: Set<MailFlag>) async throws {
        if add.contains(.deleted) {
            try await trash(messageID: messageID)
            return
        }
        var labelsToAdd: [String] = []
        var labelsToRemove: [String] = []
        for flag in add { Self.apply(flag, adding: true, to: &labelsToAdd, and: &labelsToRemove) }
        for flag in remove { Self.apply(flag, adding: false, to: &labelsToAdd, and: &labelsToRemove) }
        guard labelsToAdd.isEmpty == false || labelsToRemove.isEmpty == false else { return }
        try await client.modifyLabels(messageID: messageID, add: labelsToAdd, remove: labelsToRemove)
    }

    private func labelQuery(_ folderID: String) async throws -> String {
        if folderID == Self.allMail { return "" }
        if GmailSystemLabel.all.contains(folderID) { return "label:\(folderID)" }
        let labels = try await client.listLabels()
        guard let label = labels.first(where: { $0.id == folderID }) else { throw MailTransportError.folderNotFound(folderID) }
        let escaped = label.name.replacingOccurrences(of: "\"", with: "\\\"")
        return "label:\"\(escaped)\""
    }

    private static func apply(_ flag: MailFlag, adding: Bool, to labelsToAdd: inout [String], and labelsToRemove: inout [String]) {
        switch flag {
        case .seen:
            if adding { labelsToRemove.append(GmailSystemLabel.unread) } else { labelsToAdd.append(GmailSystemLabel.unread) }
        case .flagged:
            if adding { labelsToAdd.append(GmailSystemLabel.starred) } else { labelsToRemove.append(GmailSystemLabel.starred) }
        case .answered, .draft, .deleted:
            break
        }
    }

    private static func summary(_ message: GoogleGmailMessage) -> MailMessageSummary {
        var flags: Set<MailFlag> = []
        if message.labels.contains(GmailSystemLabel.unread) == false { flags.insert(.seen) }
        if message.labels.contains(GmailSystemLabel.starred) { flags.insert(.flagged) }
        if message.labels.contains(GmailSystemLabel.draft) { flags.insert(.draft) }
        return MailMessageSummary(
            id: message.id, threadID: message.threadID, subject: message.subject, from: message.from,
            fromRaw: message.fromRaw, toRaw: message.toRaw, ccRaw: message.ccRaw, snippet: message.snippet,
            receivedAt: message.receivedAt, flags: flags, folderIDs: message.labels,
            attachmentCount: message.attachments.count)
    }
}
