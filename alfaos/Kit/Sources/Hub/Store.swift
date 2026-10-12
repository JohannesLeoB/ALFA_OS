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
            try db.execute(sql: "CREATE TABLE IF NOT EXISTS setting (key TEXT PRIMARY KEY, value BLOB NOT NULL)")
        }
    }

    func loadInlets() throws -> [Inlet] {
        try db.read { db in
            try Row.fetchAll(db, sql: "SELECT json FROM inlet ORDER BY rowid").map { row in
                let data: Data = row["json"]
                return try JSONDecoder().decode(Inlet.self, from: data)
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

    func slots(of inlet: Inlet.ID) throws -> [String] {
        try db.read { db in
            try String.fetchAll(db, sql: "SELECT name FROM key_slot WHERE inlet = ? ORDER BY name", arguments: [inlet])
        }
    }

    func delete(_ inlet: Inlet.ID) throws {
        try db.write { db in
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
