import Foundation
import AlfaKit

public struct RecentActivityItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let timestamp: Date
    public let title: String
    public let detail: String
    public let source: RecentActivitySource
    public let isError: Bool

    public init(id: String, timestamp: Date, title: String, detail: String,
                source: RecentActivitySource, isError: Bool) {
        self.id = id; self.timestamp = timestamp; self.title = title
        self.detail = detail; self.source = source; self.isError = isError
    }
}

public enum RecentActivitySource: Sendable, Equatable { case handshake, audit }

public enum RecentActivityFeed {
    public static func recent(handshakes: [DataFlowEntry],
                              audits: [AuditEntry],
                              limit: Int = 8) -> [RecentActivityItem] {
        var items: [RecentActivityItem] = []

        for h in handshakes {
            let detail: String
            if h.action == .error {
                detail = h.errorMessage ?? "Fehler"
            } else if h.recordsRead > 0 || h.recordsWritten > 0 {
                detail = "\(h.recordsRead) gelesen · \(h.recordsWritten) geschrieben"
            } else {
                detail = h.summary
            }
            items.append(RecentActivityItem(
                id: "flow:\(h.id.uuidString)", timestamp: h.timestamp,
                title: h.integrationID, detail: detail,
                source: .handshake, isError: h.action == .error))
        }

        for a in audits {
            items.append(RecentActivityItem(
                id: "audit:\(a.id.uuidString)", timestamp: a.timestamp,
                title: a.action.timelineLabel, detail: a.summary,
                source: .audit, isError: false))
        }

        return items.sorted { $0.timestamp > $1.timestamp }.prefix(limit).map { $0 }
    }
}
