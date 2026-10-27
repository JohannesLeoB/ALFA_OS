import Core
import Foundation
import GRDB

public final class SQLiteStore: Sendable {
    private let queue: DatabaseQueue

    init(path: String? = nil) throws {
        var configuration = Configuration()
        configuration.label = AppIdentity.name
        configuration.prepareDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode = WAL")
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }
        if let path {
            queue = try DatabaseQueue(path: path, configuration: configuration)
        } else {
            queue = try DatabaseQueue(configuration: configuration)
        }
        try Self.migrator().migrate(queue)
    }

    public static func inMemory() throws -> SQLiteStore {
        try SQLiteStore()
    }

    public func read<T: Sendable>(_ block: @Sendable (Database) throws -> T) throws -> T {
        try queue.read(block)
    }

    @discardableResult
    public func write<T: Sendable>(_ block: @Sendable (Database) throws -> T) throws -> T {
        try queue.write(block)
    }
}
