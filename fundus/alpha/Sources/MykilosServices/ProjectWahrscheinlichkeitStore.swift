import Foundation
import Observation
import GRDB
import MykilosKit

private struct ProjectWahrscheinlichkeitRecord: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "projectWahrscheinlichkeit" }
    var projectNumber: String
    var historieText: String
    var updatedAt: Double
}

@MainActor
@Observable
public final class ProjectWahrscheinlichkeitStore {
    public private(set) var historien: [String: WahrscheinlichkeitHistorie] = [:]
    public private(set) var saveState: SaveState = .idle

    private let db: GRDBDatabase

    public init(db: GRDBDatabase) {
        self.db = db
    }

    public func load() throws {
        do {
            let records = try db.read { try ProjectWahrscheinlichkeitRecord.fetchAll($0) }
            var map: [String: WahrscheinlichkeitHistorie] = [:]
            for r in records {
                map[r.projectNumber] = WahrscheinlichkeitHistorie.parse(r.historieText)
            }
            historien = map
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }

    public func historie(for projectNumber: String) -> WahrscheinlichkeitHistorie {
        historien[projectNumber] ?? WahrscheinlichkeitHistorie()
    }

    public func setzeWert(_ prozent: Int, fuer projectNumber: String) throws {
        saveState = .saving
        let neueHistorie = historie(for: projectNumber).hinzugefuegt(prozent, am: Date())
        let record = ProjectWahrscheinlichkeitRecord(
            projectNumber: projectNumber, historieText: neueHistorie.airtableText,
            updatedAt: Date().timeIntervalSince1970)
        do {
            try db.write { try record.save($0) }
            historien[projectNumber] = neueHistorie
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }

    public func markiereRemote(error: String?) {
        if let error {
            saveState = .failed(error)
        } else {
            saveState = .saved(Date())
        }
    }
}
