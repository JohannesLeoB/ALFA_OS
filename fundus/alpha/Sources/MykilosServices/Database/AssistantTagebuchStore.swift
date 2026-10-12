import Foundation
import Observation
import GRDB
import MykilosKit

@MainActor
@Observable
public final class AssistantTagebuchStore {
    public private(set) var entries: [AssistantTagebuchEintrag] = []
    public private(set) var saveState: SaveState = .idle

    private let database: GRDBDatabase

    public init(db: GRDBDatabase) {
        self.database = db
    }

    public func load(projectID: String? = nil) throws {
        do {
            let records = try database.read { dbConn in
                var request = AssistantTagebuchRecord.order(Column("timestamp").desc)
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

    @discardableResult
    public func append(_ entry: AssistantTagebuchEintrag) throws -> AssistantTagebuchEintrag {
        saveState = .saving
        do {
            try database.write { dbConn in
                try AssistantTagebuchRecord(from: entry).insert(dbConn)
            }
            entries.insert(entry, at: 0)
            saveState = .saved(Date())
            return entry
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }
}

struct AssistantTagebuchRecord: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "assistantTagebuch" }

    var id: String
    var timestamp: Double
    var projectID: String?
    var art: String
    var text: String

    init(from entry: AssistantTagebuchEintrag) {
        self.id = entry.id.uuidString
        self.timestamp = entry.timestamp.timeIntervalSince1970
        self.projectID = entry.projectID
        self.art = entry.art.rawValue
        self.text = entry.text
    }

    var toDomain: AssistantTagebuchEintrag? {
        guard let id = UUID(uuidString: id),
              let art = AssistantTagebuchEintrag.Art(rawValue: art) else { return nil }
        return AssistantTagebuchEintrag(
            id: id,
            timestamp: Date(timeIntervalSince1970: timestamp),
            projectID: projectID,
            art: art,
            text: text
        )
    }
}
