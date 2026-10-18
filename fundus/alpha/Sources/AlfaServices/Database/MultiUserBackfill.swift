import Foundation
import GRDB

public enum MultiUserBackfill {
    static let isolatedTables = ["chatMessages", "assistantNotes", "assistantTasks",
                                 "timeSegmentDrafts", "timeSegments", "chatMemorySummaries"]

    public static func assignNullRowsToPrimary(db: GRDBDatabase, primaryUserID: String) throws {
        let trimmed = primaryUserID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        try db.write { dbConn in
            for table in isolatedTables {
                try dbConn.execute(
                    sql: "UPDATE \(table) SET userID = ? WHERE userID IS NULL",
                    arguments: [trimmed]
                )
            }

            try dbConn.execute(
                sql: """
                    UPDATE activeTimer SET id = ? WHERE id = 'singleton'
                    AND NOT EXISTS (SELECT 1 FROM activeTimer AS a WHERE a.id = ?)
                    """,
                arguments: [trimmed, trimmed]
            )
        }
    }
}
