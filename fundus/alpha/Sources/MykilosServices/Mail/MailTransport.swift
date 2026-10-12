import Foundation
import MykilosKit

public enum MailFolderRole: String, Sendable, CaseIterable {
    case inbox
    case sent
    case drafts
    case trash
    case spam
    case starred
    case all
    case other
}

public struct MailFolder: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var role: MailFolderRole

    public init(id: String, name: String, role: MailFolderRole = .other) {
        self.id = id
        self.name = name
        self.role = role
    }
}

public enum MailFlag: String, Sendable, CaseIterable {
    case seen
    case flagged
    case answered
    case draft
    case deleted
}

public struct MailMessageSummary: Identifiable, Equatable, Sendable {
    public var id: String
    public var threadID: String
    public var subject: String
    public var from: String
    public var fromRaw: String
    public var toRaw: String
    public var ccRaw: String
    public var snippet: String
    public var receivedAt: Date?
    public var flags: Set<MailFlag>
    public var folderIDs: [String]
    public var attachmentCount: Int

    public init(id: String, threadID: String = "", subject: String, from: String, fromRaw: String = "", toRaw: String = "",
                ccRaw: String = "", snippet: String = "", receivedAt: Date? = nil, flags: Set<MailFlag> = [],
                folderIDs: [String] = [], attachmentCount: Int = 0) {
        self.id = id
        self.threadID = threadID
        self.subject = subject
        self.from = from
        self.fromRaw = fromRaw
        self.toRaw = toRaw
        self.ccRaw = ccRaw
        self.snippet = snippet
        self.receivedAt = receivedAt
        self.flags = flags
        self.folderIDs = folderIDs
        self.attachmentCount = attachmentCount
    }
}

public struct MailMessagePage: Equatable, Sendable {
    public var messages: [MailMessageSummary]
    public var nextPageToken: String?

    public init(messages: [MailMessageSummary], nextPageToken: String? = nil) {
        self.messages = messages
        self.nextPageToken = nextPageToken
    }
}

public struct MailMessageBody: Equatable, Sendable {
    public var text: String?
    public var html: String?
    public var inlineImages: [String: String]

    public init(text: String? = nil, html: String? = nil, inlineImages: [String: String] = [:]) {
        self.text = text
        self.html = html
        self.inlineImages = inlineImages
    }
}

public enum MailTransportError: Error, Equatable, Sendable {
    case notImplemented(MailProviderKind)
    case folderNotFound(String)
    case accountIncomplete(String)
    case connectionFailed(String)
    case connectionClosed
    case timeout
    case tlsUnavailable
    case credentialsMissing
    case oauthUnavailable(MailProviderKind)
    case unsupportedAuthentication(String)
    case authenticationRejected(String)
    case serverRejected(String)
    case smtpRejected(Int, String)
    case recipientRejected(String, Int, String)
    case malformedResponse(String)
    case messageNotFound(String)
    case invalidMessageID(String)
    case invalidRecipient(String)
    case noRecipients
}

public protocol MailTransport: Sendable {
    func listFolders() async throws -> [MailFolder]

    func listMessages(folderID: String, query: String?, pageToken: String?, maxResults: Int) async throws -> MailMessagePage

    func fetchBody(messageID: String) async throws -> MailMessageBody

    func send(_ draft: EmailDraft) async throws

    func setFlags(messageID: String, add: Set<MailFlag>, remove: Set<MailFlag>) async throws
}

public enum MailTransports {
    public static func transport(for account: MailAccount) -> any MailTransport {
        switch account.provider {
        case .gmail:
            GmailMailTransport()
        case .outlook, .ionos, .gmx, .webde, .icloud, .generic:
            IMAPSMTPMailTransport(account: account)
        }
    }
}
