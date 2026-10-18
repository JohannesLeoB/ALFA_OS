import Foundation
import Observation
import GRDB
import AlfaKit

private struct ClickUpAirtableSyncStateRecord: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "clickUpAirtableSyncState" }
    var projectNumber: String
    var clickUpFeldName: String
    var letzterWert: String
    var syncedAt: Double
}

@MainActor
@Observable
public final class ClickUpAirtableSyncStateStore {
    public private(set) var values: [String: String] = [:]
    public private(set) var saveState: SaveState = .idle

    private let db: GRDBDatabase

    public init(db: GRDBDatabase) {
        self.db = db
    }

    public func load() throws {
        do {
            let records = try db.read { try ClickUpAirtableSyncStateRecord.fetchAll($0) }
            var map: [String: String] = [:]
            for r in records {
                map[Self.key(projectNumber: r.projectNumber, feld: r.clickUpFeldName)] = r.letzterWert
            }
            values = map
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }

    public func letzterWert(projectNumber: String, feld: String) -> String? {
        values[Self.key(projectNumber: projectNumber, feld: feld)]
    }

    public func setzeLetztenWert(projectNumber: String, feld: String, value: String) throws {
        saveState = .saving
        let record = ClickUpAirtableSyncStateRecord(
            projectNumber: projectNumber, clickUpFeldName: feld,
            letzterWert: value, syncedAt: Date().timeIntervalSince1970)
        do {
            try db.write { try record.save($0) }
            values[Self.key(projectNumber: projectNumber, feld: feld)] = value
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }

    private static func key(projectNumber: String, feld: String) -> String {
        "\(projectNumber)::\(feld)"
    }
}
