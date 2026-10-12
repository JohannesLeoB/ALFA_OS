import Foundation
import GRDB
import MykilosKit

public final class DriveMetadataCacheStore: Sendable {
    public static let ttl: TimeInterval = 5 * 60

    public struct Entry: Sendable {
        public let files: [GoogleDriveFile]
        public let folderName: String?
        public let fetchedAt: Date

        public var isFresh: Bool {
            Date().timeIntervalSince(fetchedAt) < DriveMetadataCacheStore.ttl
        }
    }

    private let db: GRDBDatabase

    public init(db: GRDBDatabase) {
        self.db = db
    }

    public func load(folderID: String) throws -> Entry? {
        try db.read { grdb in
            guard let row = try Row.fetchOne(grdb,
                sql: "SELECT filesJSON, folderName, fetchedAt FROM driveFolderCache WHERE folderID = ?",
                arguments: [folderID]),
                let json = (row["filesJSON"] as String?),
                let ts = (row["fetchedAt"] as Double?)
            else { return nil }
            let files = (try? JSONDecoder().decode([GoogleDriveFile].self, from: Data(json.utf8))) ?? []
            let name = row["folderName"] as String?
            return Entry(files: files, folderName: name, fetchedAt: Date(timeIntervalSince1970: ts))
        }
    }

    public func save(folderID: String, files: [GoogleDriveFile], folderName: String?) throws {
        let json = (try? String(data: JSONEncoder().encode(files), encoding: .utf8)) ?? "[]"
        let ts = Date().timeIntervalSince1970
        try db.write { grdb in
            try grdb.execute(
                sql: """
                    INSERT INTO driveFolderCache (folderID, filesJSON, folderName, fetchedAt)
                    VALUES (?, ?, ?, ?)
                    ON CONFLICT(folderID) DO UPDATE SET filesJSON=excluded.filesJSON,
                        folderName=excluded.folderName, fetchedAt=excluded.fetchedAt
                    """,
                arguments: [folderID, json, folderName, ts])
        }
    }

    public func invalidate(folderID: String) throws {
        try db.write { grdb in
            try grdb.execute(sql: "DELETE FROM driveFolderCache WHERE folderID = ?",
                             arguments: [folderID])
        }
    }

    public func invalidateAll() throws {
        try db.write { grdb in
            try grdb.execute(sql: "DELETE FROM driveFolderCache")
        }
    }
}
