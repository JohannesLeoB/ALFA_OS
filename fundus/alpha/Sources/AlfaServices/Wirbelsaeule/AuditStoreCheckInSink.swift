import Foundation
import AlfaKit

public struct AuditStoreCheckInSink: CheckInAuditSink {
    private let store: AuditStore

    public init(store: AuditStore) {
        self.store = store
    }

    public func schreibe(_ entry: AuditEntry) async throws {
        try await MainActor.run {
            try store.append(entry)
        }
    }
}
