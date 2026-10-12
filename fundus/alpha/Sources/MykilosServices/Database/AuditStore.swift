import Foundation
import Observation
import GRDB
import MykilosKit

@MainActor
@Observable
public final class AuditStore {
    public private(set) var entries: [AuditEntry] = []
    public private(set) var saveState: SaveState = .idle

    private let db: GRDBDatabase

    public init(db: GRDBDatabase) {
        self.db = db
    }

    public func load(projectID: String? = nil) throws {
        do {
            let records = try db.read { dbConn in
                var request = AuditRecord
                    .order(Column("timestamp").desc)
                if let projectID {
                    request = request.filter(Column("projectID") == projectID)
                }
                return try request.fetchAll(dbConn)
            }
            entries = records.compactMap(\.toDomain)
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }

    public func append(_ entry: AuditEntry) throws {
        saveState = .saving
        do {
            try db.write { dbConn in
                try AuditRecord(from: entry).insert(dbConn)
            }
            entries.insert(entry, at: 0)
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }

    public func entries(for projectID: String) -> [AuditEntry] {
        entries.filter { $0.projectID == projectID }
    }
}
