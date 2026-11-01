import Core
import Foundation
import GRDB
import Hub
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

public final class ClaudeUsageStore: UsagePort {
    private let database: SQLiteStore

    public init(database: SQLiteStore) {
        self.database = database
    }

    static func day(of date: Date) -> Int {
        Int((date.timeIntervalSince1970 / UsageEngine.secondsPerDay).rounded(.down))
    }

    public func book(_ usage: TokenUsage, model: String, at date: Date) {
        let day = Self.day(of: date)
        do {
            try database.write { db in
                try db.execute(sql: """
                INSERT INTO claude_usage (day, model, calls, input, output, cacheRead, cacheWrite) VALUES (?, ?, 1, ?, ?, ?, ?)
                ON CONFLICT(day, model) DO UPDATE SET
                    calls = calls + 1, input = input + excluded.input, output = output + excluded.output,
                    cacheRead = cacheRead + excluded.cacheRead, cacheWrite = cacheWrite + excluded.cacheWrite
                """, arguments: [day, model, usage.input, usage.output, usage.cacheRead, usage.cacheWrite])
            }
        } catch {
            Log.failure("UsageUnsaved", detail: String(describing: error))
        }
    }

    public func totals(from start: Date) -> UsageTotals {
        let first = Self.day(of: start)
        let found = try? database.read { db -> UsageTotals in
            guard let row = try Row.fetchOne(db, sql: """
                SELECT COALESCE(SUM(input + cacheRead + cacheWrite), 0) AS input, COALESCE(SUM(output), 0) AS output,
                       COALESCE(SUM(calls), 0) AS calls, MIN(day) AS since
                FROM claude_usage WHERE day >= ?
                """, arguments: [first]), (row["calls"] as Int? ?? 0) > 0 else { return UsageTotals() }
            let since = (row["since"] as Int?).map { Date(timeIntervalSince1970: Double($0) * UsageEngine.secondsPerDay) }
            return UsageTotals(input: row["input"], output: row["output"], calls: row["calls"], since: since)
        }
        return found ?? UsageTotals()
    }

    public func reset() {
        do {
            try database.write { db in try db.execute(sql: "DELETE FROM claude_usage") }
        } catch {
            Log.failure("UsageUnsaved", detail: String(describing: error))
        }
    }

    public func price(_ kind: UsagePrice) -> String {
        let raw = try? database.read { db in
            try String.fetchOne(db, sql: "SELECT price FROM claude_price WHERE kind = ?", arguments: [kind.rawValue])
        }
        return raw.flatMap { $0 } ?? ""
    }

    public func setPrice(_ text: String, for kind: UsagePrice) {
        try? database.write { db in
            try db.execute(sql: "INSERT INTO claude_price (kind, price) VALUES (?, ?) ON CONFLICT(kind) DO UPDATE SET price = excluded.price",
                           arguments: [kind.rawValue, text])
        }
    }
}

public struct ClaudeKeyStore: KeyPort {
    private let credential: ClaudeCredential

    public init(credential: ClaudeCredential) {
        self.credential = credential
    }

    public func claudeKey() async -> ClaudeKey? {
        await credential.current()
    }
}

public struct TextStore: TextPort {
    public init() {}

    public func text(_ key: String, _ arguments: [String]) -> String {
        PlaceholderEngine.fill(String(localized: String.LocalizationValue(key)), arguments)
    }
}
