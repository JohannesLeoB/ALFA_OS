import Foundation
import Document

/// The rows of the versions list of a card: the newest version first. Each row keeps the index that the commands take.
public struct VersionListing: Equatable, Sendable {
    public struct Row: Equatable, Sendable {
        /// The index of the version, where 0 is the oldest.
        public let index: Int
        public let date: Date
        public let reason: CardVersion.Reason
    }

    public let rows: [Row]

    public init(_ versions: [CardVersion]) {
        rows = versions.indices.reversed().map { index in
            Row(index: index, date: versions[index].date, reason: versions[index].reason)
        }
    }
}
