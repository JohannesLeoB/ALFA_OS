import Foundation

public enum MailStoreLimit: String, CaseIterable, Sendable {
    case gb1
    case gb5
    case gb10
    case gb25
    case none

    public static let standard = MailStoreLimit.none

    public var bytes: Int? {
        switch self {
        case .gb1: 1_000_000_000
        case .gb5: 5_000_000_000
        case .gb10: 10_000_000_000
        case .gb25: 25_000_000_000
        case .none: nil
        }
    }

    public var key: String {
        switch self {
        case .gb1: "settings.mailStore.limit.gb1"
        case .gb5: "settings.mailStore.limit.gb5"
        case .gb10: "settings.mailStore.limit.gb10"
        case .gb25: "settings.mailStore.limit.gb25"
        case .none: "settings.mailStore.limit.none"
        }
    }
}

public enum UndoSend: String, CaseIterable, Sendable {
    case off
    case seconds10
    case seconds20
    case seconds30

    public static let standard = UndoSend.seconds10

    public var seconds: Int {
        switch self {
        case .off: 0
        case .seconds10: 10
        case .seconds20: 20
        case .seconds30: 30
        }
    }
}

public struct MailStoreSettings: Equatable, Sendable {
    public var attachments: Bool
    public var limit: MailStoreLimit
    public var folder: Data?

    public init(attachments: Bool = false, limit: MailStoreLimit = .standard, folder: Data? = nil) {
        self.attachments = attachments
        self.limit = limit
        self.folder = folder
    }
}
