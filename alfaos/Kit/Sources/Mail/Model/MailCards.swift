import Foundation
import ShellCore
import struct AlfaServices.MailFolder

public enum CardRef: Hashable, Sendable {
    case message(String)
    case draft(UUID)

    public var id: String {
        switch self {
        case .message(let id): id
        case .draft(let id): id.uuidString
        }
    }
}

public enum MailSearchScope: Equatable, Sendable {
    case here
    case all
}

public enum MailOverviewMode: Equatable, Sendable, CaseIterable {
    case stack
    case folder
}

public struct MailOverview: Equatable, Sendable {
    public var open = false
    public var mode = MailOverviewMode.stack
    public var size = OverviewSize.medium
    public var hot: CardRef?
}

public enum MailToastKind: Equatable, Sendable {
    case archived
    case trashed
    case purged
    case draftSaved
    case recipientMissing
    case addressCopied
    case bulkRead(count: Int, read: Bool)
    case bulkArchived(count: Int)
    case bulkTrashed(count: Int)

    public var key: String {
        switch self {
        case .archived: "mail.toast.archived"
        case .trashed: "mail.toast.trashed"
        case .purged: "mail.toast.purged"
        case .draftSaved: "mail.toast.draftSaved"
        case .recipientMissing: "mail.toast.recipientMissing"
        case .addressCopied: "mail.toast.addressCopied"
        case .bulkRead(let count, let read): "mail.toast.bulkRead." + (read ? "read" : "unread") + (count == 1 ? ".one" : ".other")
        case .bulkArchived(let count): "mail.toast.bulkArchived" + (count == 1 ? ".one" : ".other")
        case .bulkTrashed(let count): "mail.toast.bulkTrashed" + (count == 1 ? ".one" : ".other")
        }
    }

    public var count: Int? {
        switch self {
        case .bulkRead(let count, _), .bulkArchived(let count), .bulkTrashed(let count): count
        default: nil
        }
    }
}

public struct MailToast: Equatable, Sendable {
    public let serial: Int
    public let kind: MailToastKind
    public let undoable: Bool
}

public struct MailFolderRow: Identifiable, Equatable, Sendable {
    public var id: String { folder.id }
    public let folder: MailFolder
    public let glyph: Icon
    public let count: Int
    public let selected: Bool
}

public enum MailDateLabel: Equatable, Sendable {
    case time(Date)
    case yesterday
    case weekday(Date)
    case day(Date)
    case draft
    case none

    public static func of(_ date: Date?, now: Date, calendar: Calendar = .current) -> MailDateLabel {
        guard let date else { return .none }
        if calendar.isDate(date, inSameDayAs: now) { return .time(date) }
        if let before = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: before) {
            return .yesterday
        }
        let start = calendar.startOfDay(for: now)
        if let week = calendar.date(byAdding: .day, value: -6, to: start), date >= week, date < start {
            return .weekday(date)
        }
        return .day(date)
    }
}
