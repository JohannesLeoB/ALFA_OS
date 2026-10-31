import Foundation
import GRDB
import Storage

public final class ExportStore: ExportPort {
    public static let contactsKey = "mail.contacts"

    private let directory: URL
    private let contacts: @Sendable () -> Data?

    public init(directory: URL = DatabaseStore.directory(),
                contacts: @escaping @Sendable () -> Data? = { UserDefaults.standard.data(forKey: ExportStore.contactsKey) }) {
        self.directory = directory
        self.contacts = contacts
    }

    public var isAvailable: Bool { DatabaseStore.size(in: directory) != nil }

    public func collect(at date: Date) throws(ExportFailure) -> ExportSource {
        guard isAvailable else { throw .unreadable }
        do {
            let database = try DatabaseStore.open(in: directory)
            var source = ExportSource(generatedAt: date)
            source.settings = try SettingStore(database: database).all()
            source.contacts = contacts()
            source.templates = TemplateStore(directory: directory.appendingPathComponent("templates", isDirectory: true)).templates.map(\.name)
            source.tables = try database.read { db in
                var tables: [ExportTable: [ExportRow]] = [:]
                for table in ExportTable.allCases { tables[table] = try Self.rows(table, db) }
                return tables
            }
            source.rawMails = try database.read { db in
                try Row.fetchAll(db, sql: "SELECT inlet, uid, raw FROM mail_pop ORDER BY inlet, uid").map { row in
                    ExportRawMail(inlet: row["inlet"], id: row["uid"], data: row["raw"])
                }
            }
            return source
        } catch {
            throw .unreadable
        }
    }

    public func save(_ data: Data, to url: URL) throws(ExportFailure) {
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw .unwritable
        }
    }

    static func rows(_ table: ExportTable, _ db: Database) throws -> [ExportRow] {
        let names = table.columns.map { "\"" + $0 + "\"" }.joined(separator: ", ")
        let sql = "SELECT " + names + " FROM \"" + table.sqlName + "\" ORDER BY " + table.orderBy
        return try Row.fetchAll(db, sql: sql).map { row in
            var result: ExportRow = [:]
            for column in table.columns {
                let stored: DatabaseValue = row[column]
                result[column] = Self.value(stored)
            }
            return result
        }
    }

    static func value(_ stored: DatabaseValue) -> ExportValue {
        switch stored.storage {
        case .null: .null
        case .int64(let number): .integer(number)
        case .double(let number): .real(number)
        case .string(let text): .text(text)
        case .blob(let data): .blob(data)
        }
    }
}
