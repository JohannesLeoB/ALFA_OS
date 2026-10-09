import Foundation

/// One backup of a document: its identifier and the time it was taken.
public struct BackupEntry: Equatable, Sendable {
    public let id: String
    public let date: Date

    public init(id: String, date: Date) {
        self.id = id
        self.date = date
    }
}

/// Decides which backups of one document to delete, so that at most `maximum` remain.
///
/// The oldest and the newest backup are never removed. Otherwise the entry whose nearest
/// neighbour in time is closest is removed, so backups taken close together thin out first.
/// A tie removes the older entry. The function is pure: it only reads the list it is given.
public enum BackupThinning {
    public static let maximum = 3

    /// The IDs to delete, in the order they were chosen. Empty when there are at most `maximum` entries.
    public static func removals(_ entries: [BackupEntry]) -> [String] {
        var remaining = entries.sorted { ($0.date, $0.id) < ($1.date, $1.id) }
        var removed: [String] = []
        while remaining.count > maximum {
            // Only the middle entries may go: index 0 (oldest) and the last index (newest) are kept.
            var best = 1
            var bestGap = gap(remaining, at: 1)
            for index in 2..<(remaining.count - 1) {
                let current = gap(remaining, at: index)
                if current < bestGap {
                    best = index
                    bestGap = current
                }
            }
            removed.append(remaining.remove(at: best).id)
        }
        return removed
    }

    /// The smaller distance from the entry at `index` to its neighbour before or after it.
    private static func gap(_ sorted: [BackupEntry], at index: Int) -> TimeInterval {
        min(sorted[index].date.timeIntervalSince(sorted[index - 1].date),
            sorted[index + 1].date.timeIntervalSince(sorted[index].date))
    }
}
