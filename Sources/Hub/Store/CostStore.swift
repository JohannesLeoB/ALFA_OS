import Foundation
import GRDB
import Storage

public final class CostStore: CostPort {
    private let database: SQLiteStore

    public init(database: SQLiteStore) {
        self.database = database
    }

    static func day(of date: Date) -> Int {
        Int((date.timeIntervalSince1970 / 86_400).rounded(.down))
    }

    public func book(_ item: CostItem) {
        let day = Self.day(of: item.at)
        try? database.write { db in
            try db.execute(sql: """
                INSERT INTO cost_day (inlet, capability, day, calls, bytes, tokens) VALUES (?, ?, ?, ?, ?, ?)
                ON CONFLICT(inlet, capability, day) DO UPDATE SET
                    calls = calls + excluded.calls, bytes = bytes + excluded.bytes, tokens = tokens + excluded.tokens
                """, arguments: [item.inlet, item.capability.rawValue, day, item.cost.calls, item.cost.bytes, item.cost.tokens])
        }
    }
}
