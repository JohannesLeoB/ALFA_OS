import Foundation
import Observation
import GRDB
import AlfaKit

private struct ProjectLifecycleRecord: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "projectLifecycleStage" }
    var projectNumber: String
    var stageIndex: Int
    var setAt: Double
}

@MainActor
@Observable
public final class ProjectLifecycleStore {
    public private(set) var stages: [String: ProjectLifecycleStage] = [:]

    public private(set) var setzZeitpunkte: [String: Date] = [:]
    public private(set) var saveState: SaveState = .idle

    private let db: GRDBDatabase

    public init(db: GRDBDatabase) {
        self.db = db
    }

    public func load() throws {
        do {
            let records = try db.read { try ProjectLifecycleRecord.fetchAll($0) }
            var map: [String: ProjectLifecycleStage] = [:]
            var zeiten: [String: Date] = [:]
            for r in records {
                if let stage = ProjectLifecycleStage(rawValue: r.stageIndex) {
                    map[r.projectNumber] = stage
                    zeiten[r.projectNumber] = Date(timeIntervalSince1970: r.setAt)
                }
            }
            stages = map
            setzZeitpunkte = zeiten
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }

    public func stage(for projectNumber: String) -> ProjectLifecycleStage? {
        stages[projectNumber]
    }

    public func setStage(_ stage: ProjectLifecycleStage, for projectNumber: String) throws {
        saveState = .saving
        let jetzt = Date()
        let record = ProjectLifecycleRecord(
            projectNumber: projectNumber, stageIndex: stage.rawValue, setAt: jetzt.timeIntervalSince1970)
        do {
            try db.write { try record.save($0) }
            stages[projectNumber] = stage
            setzZeitpunkte[projectNumber] = jetzt
            saveState = .saved(jetzt)
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }
}
