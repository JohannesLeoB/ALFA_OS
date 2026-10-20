import Foundation
import GRDB

struct Store {
    let db: DatabaseQueue

    init(_ db: DatabaseQueue) throws {
        self.db = db
        try db.write { db in
            try db.execute(sql: "CREATE TABLE IF NOT EXISTS inlet (id TEXT PRIMARY KEY, json BLOB NOT NULL)")
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS key_slot (inlet TEXT NOT NULL, name TEXT NOT NULL, PRIMARY KEY (inlet, name))
                """)
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS inlet_report (
                    seq INTEGER PRIMARY KEY AUTOINCREMENT, inlet TEXT NOT NULL, at REAL NOT NULL, json BLOB NOT NULL)
                """)
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS inlet_report_inlet ON inlet_report (inlet, seq)")
            try db.execute(sql: "CREATE TABLE IF NOT EXISTS setting (key TEXT PRIMARY KEY, value BLOB NOT NULL)")
        }
    }

    func loadInlets() throws -> [Inlet] {
        try db.read { db in
            try Row.fetchAll(db, sql: "SELECT json FROM inlet ORDER BY rowid").compactMap { row in
                let data: Data = row["json"]
                return try? JSONDecoder().decode(Inlet.self, from: data)
            }
        }
    }

    func save(_ inlet: Inlet, slots: [String]? = nil) throws {
        let data = try JSONEncoder().encode(inlet)
        try db.write { db in
            try db.execute(sql: "INSERT INTO inlet (id, json) VALUES (?, ?) ON CONFLICT(id) DO UPDATE SET json = excluded.json",
                           arguments: [inlet.id, data])
            if let slots {
                for name in slots {
                    try db.execute(sql: "INSERT OR REPLACE INTO key_slot (inlet, name) VALUES (?, ?)",
                                   arguments: [inlet.id, name])
                }
            }
        }
    }

    func loadReports() throws -> [Inlet.ID: [ReportEntry]] {
        try db.read { db in
            var result: [Inlet.ID: [ReportEntry]] = [:]
            for row in try Row.fetchAll(db, sql: "SELECT json FROM inlet_report ORDER BY seq DESC") {
                let data: Data = row["json"]
                if let entry = try? JSONDecoder().decode(ReportEntry.self, from: data) {
                    result[entry.inlet, default: []].append(entry)
                }
            }
            return result
        }
    }

    func append(_ entry: ReportEntry, limit: Int) throws {
        let data = try JSONEncoder().encode(entry)
        try db.write { db in
            try db.execute(sql: "INSERT INTO inlet_report (inlet, at, json) VALUES (?, ?, ?)",
                           arguments: [entry.inlet, entry.at.timeIntervalSince1970, data])
            try db.execute(sql: """
                DELETE FROM inlet_report WHERE inlet = ? AND seq NOT IN
                (SELECT seq FROM inlet_report WHERE inlet = ? ORDER BY seq DESC LIMIT ?)
                """, arguments: [entry.inlet, entry.inlet, limit])
        }
    }

    func slots(of inlet: Inlet.ID) throws -> [String] {
        try db.read { db in
            try String.fetchAll(db, sql: "SELECT name FROM key_slot WHERE inlet = ? ORDER BY name", arguments: [inlet])
        }
    }

    func delete(_ inlet: Inlet.ID) throws {
        try db.write { db in
            try db.execute(sql: "DELETE FROM inlet_report WHERE inlet = ?", arguments: [inlet])
            try db.execute(sql: "DELETE FROM key_slot WHERE inlet = ?", arguments: [inlet])
            try db.execute(sql: "DELETE FROM inlet WHERE id = ?", arguments: [inlet])
        }
    }

    func loadSettings() throws -> [String: Data] {
        try db.read { db in
            var result: [String: Data] = [:]
            for row in try Row.fetchAll(db, sql: "SELECT key, value FROM setting") {
                result[row["key"]] = row["value"]
            }
            return result
        }
    }

    func putSetting(_ key: String, _ value: Data) throws {
        try db.write { db in
            try db.execute(sql: "INSERT OR REPLACE INTO setting (key, value) VALUES (?, ?)", arguments: [key, value])
        }
    }

    func deleteSettings(withPrefix prefix: String) throws {
        try db.write { db in
            try db.execute(sql: "DELETE FROM setting WHERE key LIKE ?", arguments: [prefix + "%"])
        }
    }
}
