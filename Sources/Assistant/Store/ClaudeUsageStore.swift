import Foundation
import GRDB
import Storage

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
        try? database.write { db in
            try db.execute(sql: """
                INSERT INTO claude_usage (day, model, calls, input, output, cacheRead, cacheWrite) VALUES (?, ?, 1, ?, ?, ?, ?)
                ON CONFLICT(day, model) DO UPDATE SET
                    calls = calls + 1, input = input + excluded.input, output = output + excluded.output,
                    cacheRead = cacheRead + excluded.cacheRead, cacheWrite = cacheWrite + excluded.cacheWrite
                """, arguments: [day, model, usage.input, usage.output, usage.cacheRead, usage.cacheWrite])
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
        try? database.write { db in try db.execute(sql: "DELETE FROM claude_usage") }
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
