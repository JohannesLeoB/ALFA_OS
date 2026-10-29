import Foundation

public struct MessageSummary: Identifiable, Equatable, Sendable {
    public var id: String
    public var threadID: String
    public var subject: String
    public var from: String
    var fromRaw: String
    var toRaw: String
    var ccRaw: String
    public var snippet: String
    public var receivedAt: Date?
    public var flags: Set<Flag>
    var folderIDs: [String]
    var attachmentCount: Int
    var attachments: [AttachmentInfo]
    public var messageIDHeader: String

    public init(id: String, threadID: String = "", subject: String, from: String, fromRaw: String = "", toRaw: String = "",
                ccRaw: String = "", snippet: String = "", receivedAt: Date? = nil, flags: Set<Flag> = [],
                folderIDs: [String] = [], attachmentCount: Int = 0, attachments: [AttachmentInfo] = [],
                messageIDHeader: String = "") {
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
        self.attachments = attachments
        self.messageIDHeader = messageIDHeader
    }
}

public struct MessagePage: Equatable, Sendable {
    public var messages: [MessageSummary]
    public var nextPageToken: String?
    public var total: Int?

    public init(messages: [MessageSummary], nextPageToken: String? = nil, total: Int? = nil) {
        self.messages = messages
        self.nextPageToken = nextPageToken
        self.total = total
    }
}

public struct ListEntry: Identifiable, Equatable, Sendable {
    public var id: String { summary.id }
    public let summary: MessageSummary
    public let selected: Bool
    public let threadCount: Int
}

public enum Flag: String, Sendable, CaseIterable {
    case seen
    case flagged
    case answered
    case draft
    case deleted

    var imapName: String {
        switch self {
        case .seen: "\\Seen"
        case .flagged: "\\Flagged"
        case .answered: "\\Answered"
        case .draft: "\\Draft"
        case .deleted: "\\Deleted"
        }
    }

    init?(imapName: String) {
        guard let flag = Flag.allCases.first(where: { $0.imapName.lowercased() == imapName }) else { return nil }
        self = flag
    }
}
