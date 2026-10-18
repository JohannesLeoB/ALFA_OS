import Foundation
import GRDB
import Hub
import struct AlfaKit.EmailDraft
import enum AlfaServices.MailFlag
import struct AlfaServices.MailFolder
import enum AlfaServices.MailFolderRole
import struct AlfaServices.MailMessageSummary

struct MailMirror: Sendable {
    let db: DatabaseQueue

    init(_ db: DatabaseQueue) throws {
        self.db = db
        try db.write { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS mail_folder (
                    inlet TEXT NOT NULL, id TEXT NOT NULL, name TEXT NOT NULL, role TEXT NOT NULL, position INTEGER NOT NULL,
                    PRIMARY KEY (inlet, id))
                """)
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS mail_message (
                    inlet TEXT NOT NULL, folder TEXT NOT NULL, id TEXT NOT NULL, position INTEGER NOT NULL,
                    thread TEXT NOT NULL, subject TEXT NOT NULL, sender TEXT NOT NULL, fromRaw TEXT NOT NULL,
                    toRaw TEXT NOT NULL, ccRaw TEXT NOT NULL, snippet TEXT NOT NULL, receivedAt REAL,
                    flags TEXT NOT NULL, seen INTEGER NOT NULL, folderIDs TEXT NOT NULL, attachmentCount INTEGER NOT NULL,
                    PRIMARY KEY (inlet, folder, id))
                """)
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS mail_sync (
                    inlet TEXT NOT NULL, folder TEXT NOT NULL, at REAL NOT NULL, PRIMARY KEY (inlet, folder))
                """)
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS mail_outbox (
                    id TEXT PRIMARY KEY, inlet TEXT NOT NULL, draft BLOB NOT NULL, state TEXT NOT NULL,
                    hint BLOB, attempts INTEGER NOT NULL, position INTEGER NOT NULL, draftID TEXT)
                """)
            let columns = try String.fetchAll(db, sql: "SELECT name FROM pragma_table_info('mail_outbox')")
            if !columns.contains("draftID") {
                try db.execute(sql: "ALTER TABLE mail_outbox ADD COLUMN draftID TEXT")
            }
        }
    }

    func folders(_ inlet: Inlet.ID) -> [MailFolder] {
        let rows = (try? db.read { db in
            try Row.fetchAll(db, sql: "SELECT id, name, role FROM mail_folder WHERE inlet = ? ORDER BY position", arguments: [inlet])
        }) ?? []
        return rows.map {
            MailFolder(id: $0["id"], name: $0["name"], role: MailFolderRole(rawValue: $0["role"]) ?? .other)
        }
    }

    func inboxID(_ inlet: Inlet.ID) -> String? {
        folders(inlet).first { $0.role == .inbox }?.id
    }

    func replaceFolders(_ inlet: Inlet.ID, _ folders: [MailFolder]) throws {
        try db.write { db in
            try db.execute(sql: "DELETE FROM mail_folder WHERE inlet = ?", arguments: [inlet])
            for (index, folder) in folders.enumerated() {
                try db.execute(sql: "INSERT OR REPLACE INTO mail_folder (inlet, id, name, role, position) VALUES (?, ?, ?, ?, ?)",
                               arguments: [inlet, folder.id, folder.name, folder.role.rawValue, index])
            }
        }
    }

    func messages(_ inlet: Inlet.ID, folder: String) -> [MailMessageSummary] {
        let rows = (try? db.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM mail_message WHERE inlet = ? AND folder = ? ORDER BY position",
                             arguments: [inlet, folder])
        }) ?? []
        return rows.map(Self.summary)
    }

    func messageIDs(_ inlet: Inlet.ID, folder: String) -> Set<String> {
        let ids = (try? db.read { db in
            try String.fetchAll(db, sql: "SELECT id FROM mail_message WHERE inlet = ? AND folder = ?", arguments: [inlet, folder])
        }) ?? []
        return Set(ids)
    }

    func search(_ inlet: Inlet.ID, query: String) -> [MailMessageSummary] {
        let pattern = "%" + query.replacingOccurrences(of: "%", with: "") + "%"
        let rows = (try? db.read { db in
            try Row.fetchAll(db, sql: """
                SELECT * FROM mail_message WHERE inlet = ?1
                AND (subject LIKE ?2 OR sender LIKE ?2 OR fromRaw LIKE ?2 OR toRaw LIKE ?2 OR snippet LIKE ?2)
                GROUP BY id ORDER BY receivedAt DESC
                """,
                arguments: [inlet, pattern])
        }) ?? []
        return rows.map(Self.summary)
    }

    func replaceMessages(_ inlet: Inlet.ID, folder: String, _ messages: [MailMessageSummary], at date: Date) throws {
        try db.write { db in
            try db.execute(sql: "DELETE FROM mail_message WHERE inlet = ? AND folder = ?", arguments: [inlet, folder])
            for (index, message) in messages.enumerated() {
                try Self.insert(db, inlet: inlet, folder: folder, position: index, message)
            }
            try Self.stamp(db, inlet: inlet, folder: folder, at: date)
        }
    }

    func appendMessages(_ inlet: Inlet.ID, folder: String, _ messages: [MailMessageSummary], at date: Date) throws {
        try db.write { db in
            let last = try Int.fetchOne(db, sql: "SELECT MAX(position) FROM mail_message WHERE inlet = ? AND folder = ?",
                                        arguments: [inlet, folder]) ?? -1
            for (index, message) in messages.enumerated() {
                try db.execute(sql: "DELETE FROM mail_message WHERE inlet = ? AND folder = ? AND id = ?",
                               arguments: [inlet, folder, message.id])
                try Self.insert(db, inlet: inlet, folder: folder, position: last + 1 + index, message)
            }
            try Self.stamp(db, inlet: inlet, folder: folder, at: date)
        }
    }

    @discardableResult
    func remove(_ inlet: Inlet.ID, messageID: String, folder: String?) throws -> [String] {
        try db.write { db in
            var sql = "SELECT folder FROM mail_message WHERE inlet = ? AND id = ?"
            var arguments: StatementArguments = [inlet, messageID]
            if let folder {
                sql += " AND folder = ?"
                arguments += [folder]
            }
            let folders = try String.fetchAll(db, sql: sql, arguments: arguments)
            try db.execute(sql: sql.replacingOccurrences(of: "SELECT folder", with: "DELETE"), arguments: arguments)
            return folders
        }
    }

    func lastSync(_ inlet: Inlet.ID, folder: String) -> Date? {
        let value = try? db.read { db in
            try Double.fetchOne(db, sql: "SELECT at FROM mail_sync WHERE inlet = ? AND folder = ?", arguments: [inlet, folder])
        }
        return value.flatMap { $0 }.map { Date(timeIntervalSince1970: $0) }
    }

    func unread(_ inlet: Inlet.ID) -> Int {
        guard let inbox = inboxID(inlet) else { return 0 }
        let count = try? db.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM mail_message WHERE inlet = ? AND folder = ? AND seen = 0",
                             arguments: [inlet, inbox])
        }
        return count.flatMap { $0 } ?? 0
    }

    func apply(_ inlet: Inlet.ID, messageID: String, add: Set<MailFlag>, remove: Set<MailFlag>) throws {
        try db.write { db in
            let rows = try Row.fetchAll(db, sql: "SELECT folder, flags FROM mail_message WHERE inlet = ? AND id = ?",
                                        arguments: [inlet, messageID])
            for row in rows {
                var flags = Self.flags(row["flags"])
                flags.formUnion(add)
                flags.subtract(remove)
                try db.execute(sql: "UPDATE mail_message SET flags = ?, seen = ? WHERE inlet = ? AND folder = ? AND id = ?",
                               arguments: [Self.encode(flags), flags.contains(.seen) ? 1 : 0, inlet, row["folder"] as String, messageID])
            }
        }
    }

    func outbox() -> [OutboxItem] {
        let rows = (try? db.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM mail_outbox ORDER BY position")
        }) ?? []
        return rows.compactMap { row in
            guard let id = UUID(uuidString: row["id"]),
                  let draft = try? JSONDecoder().decode(EmailDraft.self, from: row["draft"] as Data) else { return nil }
            var state = OutboxState.waiting
            if (row["state"] as String) == "failed" {
                let hint = (row["hint"] as Data?).flatMap { try? JSONDecoder().decode(Hint.self, from: $0) }
                state = .failed(hint ?? Hint(text: MailTextKey.failed.rawValue))
            }
            return OutboxItem(id: id, inlet: row["inlet"], draft: draft, draftID: row["draftID"], state: state,
                              attempts: row["attempts"])
        }
    }

    func save(_ item: OutboxItem) throws {
        let draft = try JSONEncoder().encode(item.draft)
        var name = "waiting"
        var hint: Data?
        if case .failed(let value) = item.state {
            name = "failed"
            hint = try JSONEncoder().encode(value)
        }
        try db.write { db in
            let position = try Int.fetchOne(db, sql: "SELECT position FROM mail_outbox WHERE id = ?", arguments: [item.id.uuidString])
                ?? ((try Int.fetchOne(db, sql: "SELECT MAX(position) FROM mail_outbox") ?? -1) + 1)
            try db.execute(sql: "INSERT OR REPLACE INTO mail_outbox (id, inlet, draft, state, hint, attempts, position, draftID) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                           arguments: [item.id.uuidString, item.inlet, draft, name, hint, item.attempts, position, item.draftID])
        }
    }

    func remove(_ id: OutboxItem.ID) throws {
        try db.write { db in
            try db.execute(sql: "DELETE FROM mail_outbox WHERE id = ?", arguments: [id.uuidString])
        }
    }

    private static func stamp(_ db: Database, inlet: Inlet.ID, folder: String, at date: Date) throws {
        try db.execute(sql: "INSERT OR REPLACE INTO mail_sync (inlet, folder, at) VALUES (?, ?, ?)",
                       arguments: [inlet, folder, date.timeIntervalSince1970])
    }

    private static func insert(_ db: Database, inlet: Inlet.ID, folder: String, position: Int, _ m: MailMessageSummary) throws {
        try db.execute(sql: """
            INSERT OR REPLACE INTO mail_message
            (inlet, folder, id, position, thread, subject, sender, fromRaw, toRaw, ccRaw, snippet, receivedAt, flags, seen, folderIDs, attachmentCount)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [inlet, folder, m.id, position, m.threadID, m.subject, m.from, m.fromRaw, m.toRaw, m.ccRaw, m.snippet,
                        m.receivedAt?.timeIntervalSince1970, encode(m.flags), m.flags.contains(.seen) ? 1 : 0,
                        m.folderIDs.joined(separator: "\n"), m.attachmentCount])
    }

    private static func summary(_ row: Row) -> MailMessageSummary {
        let received: Double? = row["receivedAt"]
        let ids: String = row["folderIDs"]
        return MailMessageSummary(
            id: row["id"], threadID: row["thread"], subject: row["subject"], from: row["sender"], fromRaw: row["fromRaw"],
            toRaw: row["toRaw"], ccRaw: row["ccRaw"], snippet: row["snippet"],
            receivedAt: received.map { Date(timeIntervalSince1970: $0) }, flags: flags(row["flags"]),
            folderIDs: ids.isEmpty ? [] : ids.components(separatedBy: "\n"), attachmentCount: row["attachmentCount"])
    }

    private static func encode(_ flags: Set<MailFlag>) -> String {
        flags.map(\.rawValue).sorted().joined(separator: ",")
    }

    private static func flags(_ text: String) -> Set<MailFlag> {
        Set(text.split(separator: ",").compactMap { MailFlag(rawValue: String($0)) })
    }
}
