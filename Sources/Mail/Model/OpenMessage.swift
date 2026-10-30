import Core
import Hub

public struct OpenMessage: Identifiable, Equatable, Sendable {
    public var id: String { summary.id }
    public let inlet: Inlet.ID
    public var summary: MessageSummary
    public var content: MessageContent
    public var htmlParts: HTMLParts?
    public var remoteImagesAllowed = false
    public var pinned = false
    public var recipientsExpanded = false
    public var attachments: [AttachmentInfo] = []
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
    public let selected: Bool
    public let picked: Bool
    public let thread: Int?
    public let attachments: [AttachmentEntry]
    public let attachmentTotal: Int
    public let date: DateLabel
    public let subject: String?
    public let preview: String?
}
