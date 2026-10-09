import Foundation

/// How often a backup of a document is taken. Only the six steps the user can choose are valid.
public enum BackupInterval: Int, CaseIterable, Sendable {
    case minutes15 = 15
    case minutes30 = 30
    case minutes45 = 45
    case minutes60 = 60
    case minutes90 = 90
    case minutes120 = 120

    /// Used when no interval is stored.
    public static let standard: BackupInterval = .minutes30

    public var minutes: Int { rawValue }

    public var seconds: TimeInterval { TimeInterval(rawValue * 60) }

    /// Nil for every value that is not one of the six steps.
    public init?(minutes: Int) {
        self.init(rawValue: minutes)
    }
}
