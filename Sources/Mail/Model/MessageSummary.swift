import Foundation
import Hub
import Shell

public struct MessageSummary: Identifiable, Equatable, Sendable {
    public var id: String
    public var threadID: String
    public var subject: String
    public var from: String
    var fromRaw: String
    var toRaw: String
    var ccRaw: String
    var bccRaw: String
    var replyToRaw: String
    public var snippet: String
    public var receivedAt: Date?
    public var flags: Set<Flag>
    var folderIDs: [String]
    var attachmentCount: Int
    var attachments: [AttachmentInfo]
    public var messageIDHeader: String

    public init(id: String, threadID: String = "", subject: String, from: String, fromRaw: String = "", toRaw: String = "",
                ccRaw: String = "", bccRaw: String = "", replyToRaw: String = "", snippet: String = "",
                receivedAt: Date? = nil, flags: Set<Flag> = [], folderIDs: [String] = [], attachmentCount: Int = 0, attachments: [AttachmentInfo] = [],
                messageIDHeader: String = "") {
        self.id = id
        self.threadID = threadID
        self.subject = subject
        self.from = from
        self.fromRaw = fromRaw
        self.toRaw = toRaw
        self.ccRaw = ccRaw
        self.bccRaw = bccRaw
        self.replyToRaw = replyToRaw
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

public enum FolderRole: String, Sendable, CaseIterable {
    case inbox
    case sent
    case drafts
    case trash
    case spam
    case archive
    case starred
    case outbox
    case later
    case all
    case other

    public static let unseenRoles: [FolderRole] = [.spam, .archive]
    public static let countedRoles: [FolderRole] = unseenRoles + [.other]

    public var nameKey: String {
        switch self {
        case .outbox: "mail.folder.outbox"
        case .later: "mail.later.folder"
        default: "mail.role." + rawValue
        }
    }
}

public struct Folder: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var role: FolderRole

    public static let outboxID = "local:outbox"
    public static let laterID = "local:later"
    public static let starredID = "local:starred"

    public var isLocal: Bool { id.hasPrefix("local:") }

    public static func queues(_ id: String?) -> Bool { id == outboxID || id == laterID }

    public init(id: String, name: String, role: FolderRole = .other) {
        self.id = id
        self.name = name
        self.role = role
    }
}

public struct FolderEntry: Identifiable, Equatable, Sendable {
    public var id: String { folder.id }
    public let folder: Folder
    public let glyph: Icon
    public let count: Int
    public let selected: Bool
    public let attention: Bool
}

public struct FolderName: Equatable, Sendable {
    public let key: String?
    public let text: String
}

public enum EmptyKind: Equatable, Sendable {
    case loading(progress: SyncProgress?)
    case notConnected
    case failed(lastLoaded: Date?)
    case noResults(query: String, folder: FolderName)
    case noFilterMatch
    case empty(folder: FolderName)
}

public enum FolderTitle {
    public static func text(_ name: FolderName, localized: (String) -> String) -> String {
        name.key.map(localized) ?? name.text
    }
}

public struct FolderCount: Equatable, Sendable {
    public var unseen: Int
    public var total: Int

    public init(unseen: Int, total: Int) {
        self.unseen = unseen
        self.total = total
    }
}

public struct MirrorListing: Equatable, Sendable {
    public var ids: [String]
    public var hasOlder: Bool
    public var validity: String?

    public init(ids: [String], hasOlder: Bool, validity: String? = nil) {
        self.ids = ids
        self.hasOlder = hasOlder
        self.validity = validity
    }
}

public struct FlagRefresh: Equatable, Sendable {
    public var flags: [String: Set<Flag>]
    public var cursor: String?

    public init(flags: [String: Set<Flag>], cursor: String? = nil) {
        self.flags = flags
        self.cursor = cursor
    }
}

public struct SyncProgress: Equatable, Sendable {
    public var done: Int
    public var total: Int

    public init(done: Int, total: Int) {
        self.done = done
        self.total = total
    }
}

public struct SearchPage: Equatable, Sendable {
    var messages: [MessageSummary]
    var continuation: SearchContinuation?
    var skipped: [String]
    var total: Int?

    init(messages: [MessageSummary], continuation: SearchContinuation? = nil, skipped: [String] = [], total: Int? = nil) {
        self.messages = messages
        self.continuation = continuation
        self.skipped = skipped
        self.total = total
    }
}

public struct SearchContinuation: Equatable, Sendable {
    var tokens: [String: String]
}

struct MailOffering: Equatable, Sendable {
    var ranges: [MailboxRange]
    var everywhere: Bool
}

public enum DateLabel: Equatable, Sendable {
    case time(Date)
    case yesterday
    case weekday(Date)
    case upcoming(days: Int)
    case day(Date, withYear: Bool)
    case none

    public static func of(_ date: Date?, now: Date, calendar: Calendar = .current) -> DateLabel {
        guard let date else { return .none }
        if calendar.isDate(date, inSameDayAs: now) { return .time(date) }
        if let before = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: before) {
            return .yesterday
        }
        let start = calendar.startOfDay(for: now)
        if let week = calendar.date(byAdding: .day, value: -6, to: start), date >= week, date < start {
            return .weekday(date)
        }
        if let first = calendar.date(byAdding: .day, value: 1, to: start), let last = calendar.date(byAdding: .day, value: Self.upcomingDays + 1, to: start),
           date >= first, date < last {
            return .upcoming(days: calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: date)).day ?? 1)
        }
        return .day(date, withYear: calendar.component(.year, from: date) != calendar.component(.year, from: now))
    }

    static let upcomingDays = 6
}

public enum ThreadDate: Equatable, Sendable {
    case today(Date)
    case dated(Date, withYear: Bool)

    static func of(_ date: Date?, now: Date, calendar: Calendar = .current) -> ThreadDate? {
        guard let date else { return nil }
        if calendar.isDate(date, inSameDayAs: now) { return .today(date) }
        return .dated(date, withYear: calendar.component(.year, from: date) != calendar.component(.year, from: now))
    }
}
