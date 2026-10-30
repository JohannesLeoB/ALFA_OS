import Foundation
import GRDB
import Storage

struct POPStore: Sendable {
    static let columns = "uid, folder, head, snippet, attachments, seen, flagged, hidden, onServer, receivedAt, fetchedAt"

    let database: SQLiteStore
    let inlet: String

    func entries(_ folder: String) -> [POPEntry] {
        let inlet = inlet
        return (try? database.read { db in
            try Row.fetchAll(db, sql: """
                SELECT \(Self.columns) FROM mail_pop WHERE inlet = ? AND folder = ? AND hidden = 0 ORDER BY receivedAt DESC, uid DESC
                """, arguments: [inlet, folder]).map(Self.entry)
        }) ?? []
    }

    func entry(_ uid: String) -> POPEntry? {
        let inlet = inlet
        return (try? database.read { db in
            try Row.fetchOne(db, sql: "SELECT \(Self.columns) FROM mail_pop WHERE inlet = ? AND uid = ?", arguments: [inlet, uid]).map(Self.entry)
        }) ?? nil
    }

    func known() -> Set<String> {
        let inlet = inlet
        return Set((try? database.read { db in
            try String.fetchAll(db, sql: "SELECT uid FROM mail_pop WHERE inlet = ?", arguments: [inlet])
        }) ?? [])
    }

    func raw(_ uid: String) -> Data? {
        let inlet = inlet
        return (try? database.read { db in
            try Data.fetchOne(db, sql: "SELECT raw FROM mail_pop WHERE inlet = ? AND uid = ?", arguments: [inlet, uid])
        }) ?? nil
    }

    func insert(_ entry: POPEntry, raw: Data) throws {
        let inlet = inlet
        let attachments = try JSONEncoder().encode(entry.attachments)
        try database.write { db in
            try db.execute(sql: """
                INSERT OR IGNORE INTO mail_pop
                (inlet, uid, folder, head, snippet, attachments, raw, seen, flagged, hidden, onServer, receivedAt, fetchedAt)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, arguments: [inlet, entry.uid, entry.folder, entry.head, entry.snippet, attachments, raw, entry.seen,
                                 entry.flagged, entry.hidden, entry.onServer, entry.receivedAt.timeIntervalSince1970,
                                 entry.fetchedAt.timeIntervalSince1970])
        }
    }

    func setFlags(_ uid: String, seen: Bool?, flagged: Bool?, hidden: Bool?) throws {
        let inlet = inlet
        try database.write { db in
            if let seen {
                try db.execute(sql: "UPDATE mail_pop SET seen = ? WHERE inlet = ? AND uid = ?", arguments: [seen, inlet, uid])
            }
            if let flagged {
                try db.execute(sql: "UPDATE mail_pop SET flagged = ? WHERE inlet = ? AND uid = ?", arguments: [flagged, inlet, uid])
            }
            if let hidden {
                try db.execute(sql: "UPDATE mail_pop SET hidden = ? WHERE inlet = ? AND uid = ?", arguments: [hidden, inlet, uid])
            }
        }
    }

    func place(_ uid: String, in folder: String) throws {
        let inlet = inlet
        try database.write { db in
            try db.execute(sql: "UPDATE mail_pop SET folder = ?, hidden = 0 WHERE inlet = ? AND uid = ?", arguments: [folder, inlet, uid])
        }
    }

    func remove(_ uid: String) throws {
        let inlet = inlet
        try database.write { db in
            try db.execute(sql: "DELETE FROM mail_pop WHERE inlet = ? AND uid = ?", arguments: [inlet, uid])
        }
    }

    func leftServer(_ uids: Set<String>) throws {
        guard !uids.isEmpty else { return }
        let inlet = inlet
        let list = uids.sorted()
        let marks = Array(repeating: "?", count: list.count).joined(separator: ",")
        try database.write { db in
            try db.execute(sql: "UPDATE mail_pop SET onServer = 0 WHERE inlet = ? AND uid IN (\(marks))",
                           arguments: StatementArguments([inlet] + list))
        }
    }

    func onServer() -> [POPEntry] {
        let inlet = inlet
        return (try? database.read { db in
            try Row.fetchAll(db, sql: "SELECT \(Self.columns) FROM mail_pop WHERE inlet = ? AND onServer = 1", arguments: [inlet]).map(Self.entry)
        }) ?? []
    }

    private static func entry(_ row: Row) -> POPEntry {
        let attachments = (try? JSONDecoder().decode([AttachmentInfo].self, from: row["attachments"] as Data)) ?? []
        return POPEntry(uid: row["uid"], folder: row["folder"], head: row["head"], snippet: row["snippet"],
                        attachments: attachments, seen: row["seen"], flagged: row["flagged"], hidden: row["hidden"],
                        onServer: row["onServer"], receivedAt: Date(timeIntervalSince1970: row["receivedAt"]),
                        fetchedAt: Date(timeIntervalSince1970: row["fetchedAt"]))
    }
}

struct POPEntry: Equatable, Sendable {
    var uid: String
    var folder: String
    var head: Data
    var snippet: String
    var attachments: [AttachmentInfo]
    var seen: Bool
    var flagged: Bool
    var hidden: Bool
    var onServer: Bool
    var receivedAt: Date
    var fetchedAt: Date

    var flags: Set<Flag> {
        var flags: Set<Flag> = []
        if seen { flags.insert(.seen) }
        if flagged { flags.insert(.flagged) }
        return flags
    }
}
