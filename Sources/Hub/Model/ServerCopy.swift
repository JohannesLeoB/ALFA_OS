import Foundation

public enum ServerCopy: String, CaseIterable, Sendable {
    case keep
    case day
    case week
    case month
    case deleted

    public static let standard = ServerCopy.keep

    public var days: Int? {
        switch self {
        case .day: 1
        case .week: 7
        case .month: 30
        case .keep, .deleted: nil
        }
    }

    public var key: String { "settings.account.serverCopy." + rawValue }
}
