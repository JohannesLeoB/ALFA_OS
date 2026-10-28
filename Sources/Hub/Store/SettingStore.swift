import Foundation
import GRDB
import Storage

public final class SettingStore: Sendable {
    private let database: SQLiteStore

    public init(database: SQLiteStore) {
        self.database = database
    }

    func all() throws -> [String: Data] {
        try database.read { db in
            var result: [String: Data] = [:]
            for row in try Row.fetchAll(db, sql: "SELECT key, value FROM setting") {
                result[row["key"]] = row["value"]
            }
            return result
        }
    }

    func put(_ key: String, _ value: Data) throws {
        try database.write { db in
            try db.execute(sql: "INSERT OR REPLACE INTO setting (key, value) VALUES (?, ?)", arguments: [key, value])
        }
    }

    public func value<V: Decodable>(_ key: String, as type: V.Type) throws -> V? {
        let data: Data? = try database.read { db in
            try Data.fetchOne(db, sql: "SELECT value FROM setting WHERE key = ?", arguments: [key])
        }
        return Self.decoded(data, as: type)
    }

    public func store<V: Encodable>(_ value: V, forKey key: String) throws {
        try put(key, JSONEncoder().encode(value))
    }

    func remove(key: String) throws {
        try database.write { db in
            try db.execute(sql: "DELETE FROM setting WHERE key = ?", arguments: [key])
        }
    }

    func remove(withPrefix prefix: String) throws {
        try database.write { db in
            try db.execute(sql: "DELETE FROM setting WHERE instr(key, ?) = 1", arguments: [prefix])
        }
    }

    static func decoded<V: Decodable>(_ data: Data?, as type: V.Type) -> V? {
        data.flatMap { try? JSONDecoder().decode(type, from: $0) }
    }
}
