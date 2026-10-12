import Foundation
import MykilosKit

public struct GmailMailTransport: MailTransport {
    private let client: GoogleGmailClient

    public init(client: GoogleGmailClient = GmailAccess.client()) {
        self.client = client
    }

    public func listFolders() async throws -> [MailFolder] {
        try await client.listLabels().map { MailFolder(id: $0.id, name: $0.name, role: Self.role(of: $0.id)) }
    }

    public func listMessages(folderID: String, query: String?, pageToken: String?, maxResults: Int) async throws -> MailMessagePage {
        let scope = try await labelQuery(folderID)
        let combined = [scope, query].compactMap { $0 }.filter { $0.isEmpty == false }.joined(separator: " ")
        let page = try await client.listMessages(query: combined, maxResults: maxResults, pageToken: pageToken)
        return MailMessagePage(messages: page.messages.map(Self.summary), nextPageToken: page.nextPageToken)
    }

    public func fetchBody(messageID: String) async throws -> MailMessageBody {
        let body = try await client.fetchMailBody(messageID: messageID)
        return MailMessageBody(text: body.text, html: body.html, inlineImages: body.inlineImages)
    }

    public func send(_ draft: EmailDraft) async throws {
        try await client.sendMessage(draft)
    }

    public func setFlags(messageID: String, add: Set<MailFlag>, remove: Set<MailFlag>) async throws {
        if add.contains(.deleted) {
            try await client.trashMessage(messageID: messageID)
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

    private static func role(of labelID: String) -> MailFolderRole {
        switch labelID {
        case GmailSystemLabel.inbox: .inbox
        case GmailSystemLabel.sent: .sent
        case GmailSystemLabel.draft: .drafts
        case GmailSystemLabel.trash: .trash
        case GmailSystemLabel.spam: .spam
        default: .other
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
