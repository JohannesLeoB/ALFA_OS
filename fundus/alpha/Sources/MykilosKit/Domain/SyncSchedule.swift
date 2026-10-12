import Foundation

public enum SyncInterval: String, CaseIterable, Sendable {
    case off
    case manual
    case halfMinute
    case oneMinute
    case fiveMinutes
    case fifteenMinutes
    case thirtyMinutes
    case oneHour

    public var seconds: TimeInterval? {
        switch self {
        case .off, .manual: nil
        case .halfMinute: 30
        case .oneMinute: 60
        case .fiveMinutes: 300
        case .fifteenMinutes: 900
        case .thirtyMinutes: 1800
        case .oneHour: 3600
        }
    }

    public var runsOnSchedule: Bool { seconds != nil }

    public var allowsManualRun: Bool { self != .off }
}

extension SyncArea {
    public static let mail = SyncArea("mail")
    public static let projects = SyncArea("projects")
    public static let contacts = SyncArea("contacts")
    public static let files = SyncArea("files")
    public static let shipments = SyncArea("shipments")
    public static let phases = SyncArea("phases")
    public static let taskFields = SyncArea("taskfields")

    public static let all: [SyncArea] = [.mail, .projects, .contacts, .files, .shipments, .phases, .taskFields]

    public init?(knownID: String) {
        guard let found = Self.all.first(where: { $0.id == knownID }) else { return nil }
        self = found
    }

    public var defaultInterval: SyncInterval { .manual }
}

public struct SyncScheduleStore: Sendable {
    nonisolated(unsafe) private let defaults: UserDefaults

    public static let keyPrefix = "sync.interval."

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func key(for area: SyncArea) -> String { Self.keyPrefix + area.id }

    public func interval(for area: SyncArea) -> SyncInterval {
        defaults.string(forKey: key(for: area)).flatMap(SyncInterval.init(rawValue:)) ?? area.defaultInterval
    }

    public func set(_ interval: SyncInterval, for area: SyncArea) {
        defaults.set(interval.rawValue, forKey: key(for: area))
    }
}
