import Foundation

/// When the crash copy of a document is due. Pure: the caller passes the times, so tests set the clock.
///
/// Rules: a write is due 30 seconds after the last change. While changes keep coming, a write is due
/// 10 minutes after the first pending change, so the copy never falls far behind. Two writes are at least
/// 60 seconds apart.
public struct AutosaveSchedule: Equatable, Sendable {
    public static let quietPeriod: TimeInterval = 30
    public static let maximumAge: TimeInterval = 600
    public static let spacing: TimeInterval = 60

    /// The most recent change since the last write or clean save.
    public private(set) var lastChange: Date?
    /// The first change since the last write or clean save.
    public private(set) var pendingSince: Date?
    /// The time of the last write of the crash copy.
    public private(set) var lastWrite: Date?

    public init() {}

    public var isPending: Bool { pendingSince != nil }

    public mutating func noteChange(at date: Date) {
        lastChange = date
        if pendingSince == nil { pendingSince = date }
    }

    public mutating func noteWritten(at date: Date) {
        lastWrite = date
        pendingSince = nil
    }

    /// A clean save or close: the crash copy is no longer needed, so nothing is pending.
    public mutating func noteSaved() {
        lastChange = nil
        pendingSince = nil
    }

    /// The earliest time a write is due, or nil when nothing is pending.
    public func dueDate() -> Date? {
        guard let lastChange, let pendingSince else { return nil }
        var due = min(lastChange.addingTimeInterval(Self.quietPeriod),
                      pendingSince.addingTimeInterval(Self.maximumAge))
        if let lastWrite {
            due = max(due, lastWrite.addingTimeInterval(Self.spacing))
        }
        return due
    }

    public func isDue(at now: Date) -> Bool {
        guard let due = dueDate() else { return false }
        return now >= due
    }
}
