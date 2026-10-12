import Foundation
import GRDB

public final class CountingCost: CostPort, @unchecked Sendable {
    private let database: DatabaseQueue

    public init(_ database: DatabaseQueue) throws {
        self.database = database
        try database.write { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS cost_day (
                    inlet TEXT NOT NULL, capability TEXT NOT NULL, day INTEGER NOT NULL,
                    calls INTEGER NOT NULL DEFAULT 0, bytes INTEGER NOT NULL DEFAULT 0, tokens INTEGER NOT NULL DEFAULT 0,
                    PRIMARY KEY (inlet, capability, day))
                """)
        }
    }

    static func day(of date: Date) -> Int {
        Int((date.timeIntervalSince1970 / 86_400).rounded(.down))
    }

    public func book(_ item: CostItem) {
        try? database.write { db in
            try db.execute(sql: """
                INSERT INTO cost_day (inlet, capability, day, calls, bytes, tokens) VALUES (?, ?, ?, ?, ?, ?)
                ON CONFLICT(inlet, capability, day) DO UPDATE SET
                    calls = calls + excluded.calls, bytes = bytes + excluded.bytes, tokens = tokens + excluded.tokens
                """, arguments: [item.inlet, item.capability.rawValue, Self.day(of: item.at),
                                 item.cost.calls, item.cost.bytes, item.cost.tokens])
        }
    }

    public func sum(_ inlet: Inlet.ID, _ period: Period) -> Cost {
        let row = try? database.read { db in
            try Row.fetchOne(db, sql: """
                SELECT COALESCE(SUM(calls), 0) AS calls, COALESCE(SUM(bytes), 0) AS bytes, COALESCE(SUM(tokens), 0) AS tokens
                FROM cost_day WHERE inlet = ? AND day >= ? AND day <= ?
                """, arguments: [inlet, Self.day(of: period.from), Self.day(of: period.to)])
        }
        guard let row else { return .zero }
        return Cost(calls: row["calls"], bytes: row["bytes"], tokens: row["tokens"])
    }
}
