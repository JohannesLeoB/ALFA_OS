import Foundation
import GRDB
import Storage

struct BookedRowStore: Sendable {
    private struct Record: Codable, FetchableRecord, PersistableRecord {
        static var databaseTableName: String { "bookedRows" }

        var rowID: String
        var clockodoEntryID: String
        var bookedAt: Double
        var userID: String
    }

    private let database: SQLiteStore

    init(database: SQLiteStore) {
        self.database = database
    }

    func bookedIDs(userID: String) throws -> Set<UUID> {
        let records = try database.read { db in
            try Record.filter(Column("userID") == userID).fetchAll(db)
        }
        return Set(records.compactMap { UUID(uuidString: $0.rowID) })
    }

    func mark(rowID: UUID, entryID: String, userID: String, at date: Date = Date()) throws {
        let record = Record(
            rowID: rowID.uuidString, clockodoEntryID: entryID, bookedAt: date.timeIntervalSince1970, userID: userID)
        try database.write { db in
            try record.insert(db)
        }
    }
}
