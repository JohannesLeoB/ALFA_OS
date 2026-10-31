import Foundation
import Hub
import Mail

struct GmailMailClient: GmailPort, SourcePort, LabelPort, SenderPort, UntrashPort {
    typealias Backend = GmailFetchPort & GmailWritePort & GmailDraftPort & GmailLabelPort & GmailSenderPort

    static let allMail = "ALL"
    static let threadLimit = 20
    static let idPage = 500
    static let historyFallback = 100
    static let everywhereScope = "-in:spam -in:trash"
    static let systemFolders: [Folder] = [
        Folder(id: GmailSystemLabel.inbox, name: GmailSystemLabel.inbox, role: .inbox),
        Folder(id: GmailSystemLabel.starred, name: GmailSystemLabel.starred, role: .starred),
        Folder(id: GmailSystemLabel.sent, name: GmailSystemLabel.sent, role: .sent),
        Folder(id: GmailSystemLabel.draft, name: GmailSystemLabel.draft, role: .drafts),
        Folder(id: allMail, name: allMail, role: .all),
        Folder(id: GmailSystemLabel.spam, name: GmailSystemLabel.spam, role: .spam),
        Folder(id: GmailSystemLabel.trash, name: GmailSystemLabel.trash, role: .trash),
    ]

    let gmail: any Backend

    func listFolders() async throws -> [Folder] {
        let labels = try await gmail.listLabels().map { Folder(id: $0.id, name: $0.name, role: .other) }
        return Self.systemFolders + labels
    }

    func listMessages(folderID: String, query: String?, pageToken: String?, maxResults: Int) async throws -> MessagePage {
        let combined = Self.join(try await labelQuery(folderID), query)
        let page = try await gmail.listIDs(query: combined, maxResults: maxResults, pageToken: pageToken)
        guard !page.ids.isEmpty else { return MessagePage(messages: [], nextPageToken: page.nextPageToken, total: page.estimate) }
        let found = try await gmail.fetchMetadata(ids: page.ids)
        return MessagePage(messages: found.map(Self.summary), nextPageToken: page.nextPageToken, total: page.estimate)
    }

    func fetchBody(messageID: String) async throws -> MessageBody {
        let body = try await gmail.fetchMailBody(messageID: messageID)
        return MessageBody(text: body.text, html: body.html, inlineImages: body.inlineImages,
                           attachments: body.attachments.map(Self.info))
    }

    func send(_ draft: Draft) async throws {
        try await gmail.sendMessage(draft)
    }

    func setFlags(messageID: String, add: Set<Flag>, remove: Set<Flag>) async throws {
        if add.contains(.deleted) {
            try await trash(messageID: messageID, folderID: nil)
            return
        }
        var labelsToAdd: [String] = []
        var labelsToRemove: [String] = []
        for flag in add { Self.apply(flag, adding: true, to: &labelsToAdd, and: &labelsToRemove) }
        for flag in remove { Self.apply(flag, adding: false, to: &labelsToAdd, and: &labelsToRemove) }
        guard !labelsToAdd.isEmpty || !labelsToRemove.isEmpty else { return }
        try await gmail.modifyLabels(messageID: messageID, add: labelsToAdd, remove: labelsToRemove)
    }

    func archive(messageID: String, folderID: String?) async throws {
        try await gmail.modifyLabels(messageID: messageID, add: [], remove: [GmailSystemLabel.inbox])
    }

    func move(messageID: String, toFolderID: String) async throws {
        switch toFolderID {
        case GmailSystemLabel.trash:
            try await gmail.trashMessage(messageID: messageID)
        case GmailSystemLabel.spam:
            try await gmail.markSpam(messageID: messageID)
        case Self.allMail:
            try await archive(messageID: messageID, folderID: nil)
        case GmailSystemLabel.inbox:
            try await gmail.modifyLabels(messageID: messageID, add: [GmailSystemLabel.inbox], remove: [GmailSystemLabel.spam])
        case GmailSystemLabel.starred, GmailSystemLabel.sent, GmailSystemLabel.draft:
            throw MailFailure.folderNotFound(toFolderID)
        default:
            try await gmail.modifyLabels(messageID: messageID, add: [toFolderID], remove: [GmailSystemLabel.inbox])
        }
    }

    func trash(messageID: String, folderID: String?) async throws {
        try await gmail.trashMessage(messageID: messageID)
    }

    func markSpam(messageID: String, folderID: String?) async throws {
        try await gmail.markSpam(messageID: messageID)
    }

    func untrash(messageID: String) async throws {
        try await gmail.untrashMessage(messageID: messageID)
    }

    var usesLabels: Bool { true }

    var offersSource: Bool { true }

    func senders() async throws -> [Participant] {
        try await gmail.listSendAs()
    }

    func fetchSource(messageID: String) async throws -> Data {
        try await gmail.fetchRaw(messageID: messageID)
    }

    func fetchAttachment(messageID: String, attachmentID: String) async throws -> Data {
        try await gmail.downloadAttachment(messageID: messageID, attachmentID: attachmentID)
    }

    func fetchThread(messageID: String, threadID: String) async throws -> [MessageSummary] {
        try await gmail.fetchThread(threadID: threadID, maxMessages: Self.threadLimit).map(Self.summary)
    }

    func saveDraft(_ draft: Draft, replacing draftID: String?, into folderID: String?) async throws -> SavedDraft {
        if let draftID { return try await gmail.updateDraft(id: draftID, draft: draft) }
        return try await gmail.createDraft(draft)
    }

    func fetchDraft(messageID: String) async throws -> StoredDraft {
        guard let draftID = try await gmail.listDraftIDMap()[messageID] else { throw MailFailure.messageNotFound(messageID) }
        return StoredDraft(id: draftID, draft: try await gmail.getDraft(id: draftID))
    }

    func deleteDraft(id: String) async throws {
        try await gmail.deleteDraft(id: id)
    }

    func sendDraft(id: String) async throws {
        try await gmail.sendDraft(id: id)
    }

    func wasSent(messageID: String, in folderID: String?) async throws -> Bool {
        let query = "in:sent rfc822msgid:\(messageID)@\(DraftMimeEngine.messageIDDomain)"
        return try await !gmail.searchMessages(query: query, maxResults: 1).isEmpty
    }

    func labelQuery(_ folderID: String) async throws -> String {
        if folderID == Self.allMail { return "" }
        if GmailSystemLabel.all.contains(folderID) { return "label:\(folderID)" }
        guard let label = try await gmail.listLabels().first(where: { $0.id == folderID }) else {
            throw MailFailure.folderNotFound(folderID)
        }
        return "label:\"\(label.name.replacingOccurrences(of: "\"", with: "\\\""))\""
    }

    static func join(_ parts: String?...) -> String {
        parts.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
    }

    static func flags(_ labels: [String]) -> Set<Flag> {
        var flags: Set<Flag> = []
        if !labels.contains(GmailSystemLabel.unread) { flags.insert(.seen) }
        if labels.contains(GmailSystemLabel.starred) { flags.insert(.flagged) }
        if labels.contains(GmailSystemLabel.draft) { flags.insert(.draft) }
        return flags
    }

    private static func apply(_ flag: Flag, adding: Bool, to labelsToAdd: inout [String], and labelsToRemove: inout [String]) {
        switch flag {
        case .seen:
            if adding { labelsToRemove.append(GmailSystemLabel.unread) } else { labelsToAdd.append(GmailSystemLabel.unread) }
        case .flagged:
            if adding { labelsToAdd.append(GmailSystemLabel.starred) } else { labelsToRemove.append(GmailSystemLabel.starred) }
        case .answered, .draft, .deleted:
            break
        }
    }

    private static func info(_ attachment: GmailAttachment) -> AttachmentInfo {
        AttachmentInfo(id: attachment.attachmentID, filename: attachment.filename, mimeType: attachment.mimeType,
                       sizeBytes: attachment.sizeBytes)
    }

    static func summary(_ message: GmailMessage) -> MessageSummary {
        let attachments = message.attachments.map(info)
        return MessageSummary(
            id: message.id, threadID: message.threadID, subject: message.subject, from: message.from,
            fromRaw: message.fromRaw, toRaw: message.toRaw, ccRaw: message.ccRaw, bccRaw: message.bccRaw, replyToRaw: message.replyToRaw, snippet: message.snippet,
            receivedAt: message.receivedAt, flags: flags(message.labels), folderIDs: message.labels,
            attachmentCount: max(attachments.count, message.likelyAttachments ? 1 : 0), attachments: attachments, messageIDHeader: message.messageIDHeader)
    }
}
