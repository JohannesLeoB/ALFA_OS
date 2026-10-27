import Foundation
import GRDB
import Storage

private struct StoredJournalEntry: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "assistantJournal" }

    var id: String
    var timestamp: Double
    var projectID: String?
    var kind: String
    var text: String

    init(_ entry: JournalEntry) {
        id = entry.id.uuidString
        timestamp = entry.timestamp.timeIntervalSince1970
        projectID = entry.projectID
        kind = entry.kind.rawValue
        text = entry.text
    }

    var entry: JournalEntry? {
        guard let uuid = UUID(uuidString: id), let parsed = JournalEntry.Kind(rawValue: kind) else { return nil }
        return JournalEntry(id: uuid, timestamp: Date(timeIntervalSince1970: timestamp), projectID: projectID,
                            kind: parsed, text: text)
    }
}

public actor JournalStore {
    private let database: SQLiteStore

    public init(database: SQLiteStore) {
        self.database = database
    }

    public func entries(projectID: String? = nil) throws -> [JournalEntry] {
        try database.read { db in
            var request = StoredJournalEntry.order(Column("timestamp").desc)
            if let projectID { request = request.filter(Column("projectID") == projectID) }
            return try request.fetchAll(db)
        }.compactMap(\.entry)
    }

    @discardableResult
    public func append(_ entry: JournalEntry) throws -> JournalEntry {
        let record = StoredJournalEntry(entry)
        try database.write { db in try record.insert(db) }
        return entry
    }
}
