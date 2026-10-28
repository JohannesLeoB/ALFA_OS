import Foundation
import GRDB
import Storage

public struct PrivacyStore: PrivacyPort {
    static let rowID = "local"

    private let database: SQLiteStore

    public init(database: SQLiteStore) {
        self.database = database
    }

    static func column(_ category: PrivacyCategory) -> String {
        switch category {
        case .mail: "shareMail"
        case .calendar: "shareCalendar"
        case .contacts: "shareContacts"
        case .drive: "shareDrive"
        case .clickUp: "shareClickUp"
        case .notes: "shareNotes"
        case .tasks: "shareTasks"
        case .catalogCalculation: "shareCatalogCalculation"
        case .studioKnowledge: "shareStudioKnowledge"
        case .chat: "shareChat"
        case .time: "shareClockodo"
        }
    }

    public func load() throws -> PrivacySettings {
        let disabled: [String]? = try database.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM privacyPreferences WHERE id = ?", arguments: [Self.rowID]) else {
                return nil
            }
            return PrivacyCategory.allCases.filter { category in
                let shared: Bool = row[Self.column(category)] ?? true
                return shared == false
            }.map(\.rawValue)
        }
        return PrivacySettings(disabled: Set((disabled ?? []).compactMap(PrivacyCategory.init(rawValue:))))
    }

    public func save(_ settings: PrivacySettings, now: Date = Date()) throws {
        let columns = PrivacyCategory.allCases.map(Self.column)
        let names = (["id"] + columns + ["updatedAt"]).joined(separator: ", ")
        let marks = Array(repeating: "?", count: columns.count + 2).joined(separator: ", ")
        var values: [any DatabaseValueConvertible] = [Self.rowID]
        values += PrivacyCategory.allCases.map { settings.shares($0) }
        values.append(now.timeIntervalSince1970)
        let arguments = StatementArguments(values) ?? StatementArguments()
        try database.write { db in
            try db.execute(sql: "INSERT OR REPLACE INTO privacyPreferences (\(names)) VALUES (\(marks))", arguments: arguments)
        }
    }
}
