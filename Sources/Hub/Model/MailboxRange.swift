import Foundation

public enum MailboxRange: String, CaseIterable, Sendable {
    case days30
    case days90
    case year
    case all

    public static let standard = MailboxRange.days30
    public static let earliest = Date(timeIntervalSince1970: 631_152_000)

    public var days: Int? {
        switch self {
        case .days30: 30
        case .days90: 90
        case .year: 365
        case .all: nil
        }
    }

    public func cutoff(from now: Date) -> Date? {
        days.map { now.addingTimeInterval(-Double($0) * 86_400) }
    }

    public func resolved(in offered: [MailboxRange]) -> MailboxRange {
        if offered.contains(self) { return self }
        return offered.contains(.standard) ? .standard : (offered.first ?? .standard)
    }

    public var key: String { "settings.account.range." + rawValue }
}
