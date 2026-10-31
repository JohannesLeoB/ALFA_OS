import Core
import Foundation
import Hub

public struct MessageBody: Equatable, Sendable {
    public var text: String?
    public var html: String?
    public var inlineImages: [String: String]
    public var attachments: [AttachmentInfo]
    public var unsubscribe: ListUnsubscribe?

    public init(text: String? = nil, html: String? = nil, inlineImages: [String: String] = [:],
                attachments: [AttachmentInfo] = [], unsubscribe: ListUnsubscribe? = nil) {
        self.text = text
        self.html = html
        self.inlineImages = inlineImages
        self.attachments = attachments
        self.unsubscribe = unsubscribe
    }
}

public enum MessageContent: Equatable, Sendable {
    case bodyLoading
    case text(String)
    case html(String, inlineImages: [String: String])
}

public struct MessageDocument: Equatable, Sendable {
    public let name: String
    public let data: Data
}

public struct AttachmentInfo: Equatable, Sendable, Codable {
    var id: String
    var filename: String
    var mimeType: String
    var sizeBytes: Int

    public init(id: String, filename: String, mimeType: String, sizeBytes: Int) {
        self.id = id
        self.filename = filename
        self.mimeType = mimeType
        self.sizeBytes = sizeBytes
    }
}

public struct AttachmentEntry: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let size: String
}

struct OutgoingMessage: Equatable, Sendable {
    var data: Data
    var sender: String
    var recipients: [String]
}

public struct OpenMessage: Identifiable, Equatable, Sendable {
    public var id: String { summary.id }
    public let inlet: Inlet.ID
    public var summary: MessageSummary
    public var content: MessageContent
    public var htmlParts: HTMLParts?
    public var bodyFailed = false
    public var remoteImagesAllowed = false
    public var pinned = false
    public var recipientsExpanded = false
    public var attachments: [AttachmentInfo] = []
    public var unsubscribe: ListUnsubscribe?
    public var unsubscribed = false
    public var conversation: [MessageSummary] = []
    public var threadTexts: [String: String] = [:]
    public var quotesOpen: Set<String> = []

    public func remoteImagesBlocked(loadRemote: Bool) -> Bool {
        guard case .html = content, htmlParts?.remote == true else { return false }
        return !remoteImagesAllowed && !loadRemote
    }

    public var plainText: String? {
        switch content {
        case .text(let text): text
        case .html(let html, _): HTMLEngine.plain(html)
        case .bodyLoading: nil
        }
    }

    public var recipients: Recipients {
        Recipients(to: RecipientEngine.parse(summary.toRaw), cc: RecipientEngine.parse(summary.ccRaw))
    }

    public var attachmentEntries: [AttachmentEntry] {
        attachments.map { AttachmentEntry(id: $0.id, name: $0.filename, size: Format.bytes($0.sizeBytes)) }
    }

    public var hasConversation: Bool { conversation.count > 1 }

    public var listNotice: ListUnsubscribe? { unsubscribed ? nil : unsubscribe }
}

public struct RowPresentation: Identifiable, Equatable, Sendable {
    public let id: String
    public let initials: String
    public let sender: String
    public let address: String
    public let outgoing: Bool
    public let draft: Bool
    public let unread: Bool
    public let starred: Bool
    public let answered: Bool
    public let selected: Bool
    public let picked: Bool
    public let thread: Int?
    public let attachments: [AttachmentEntry]
    public let attachmentTotal: Int
    public let date: DateLabel
    public let subject: String?
    public let preview: String?
    public let outbox: OutboxState?
}

public struct ThreadItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let address: String
    public let date: ThreadDate?
    public let text: String
    public let html: String?
    public let blockedHTML: String?
    public let quote: Quote?
    public let quoteOpen: Bool
    public let signature: Quote?
    public let signatureOpen: Bool
    public let recipients: Recipients
    public let current: Bool
}

public struct Quote: Equatable, Sendable {
    public let text: String
    public let lines: Int
}

public struct HTMLParts: Equatable, Sendable {
    public let body: String
    public let blockedBody: String
    public let quote: Quote?
    public let remote: Bool
}

struct HTMLToken: Equatable, Sendable {
    enum Kind: Sendable {
        case text
        case raw
        case start
        case end
    }

    var kind: Kind
    var name: String
    var attributes: [String: String]
    var selfClosing: Bool
    var raw: String

    static func text(_ raw: String, kind: Kind = .text) -> HTMLToken {
        HTMLToken(kind: kind, name: "", attributes: [:], selfClosing: false, raw: raw)
    }

    var isVoid: Bool {
        selfClosing || HTMLToken.voidNames.contains(name)
    }

    static let voidNames: Set<String> = [
        "br", "hr", "img", "input", "meta", "link", "wbr", "area", "base", "col", "source", "embed", "track", "param"
    ]
}

struct StoredAttachment: Equatable, Sendable {
    var inlet: String
    var message: String
    var attachment: String
    var path: String
    var size: Int
    var receivedAt: Date?
    var storedAt: Date

    var age: Date { receivedAt ?? storedAt }

    var identity: String { inlet + "\n" + message + "\n" + attachment }
}
