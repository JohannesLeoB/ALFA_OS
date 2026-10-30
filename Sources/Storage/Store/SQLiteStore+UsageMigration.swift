import GRDB

extension SQLiteStore {
    static func registerUsage(in migrator: inout DatabaseMigrator) {
        migrator.registerMigration("claudeUsage") { db in
            try db.execute(sql: """
                CREATE TABLE claude_usage (
                    day INTEGER NOT NULL, model TEXT NOT NULL, calls INTEGER NOT NULL, input INTEGER NOT NULL,
                    output INTEGER NOT NULL, cacheRead INTEGER NOT NULL, cacheWrite INTEGER NOT NULL,
                    PRIMARY KEY (day, model))
                """)
            try db.execute(sql: "CREATE TABLE claude_price (kind TEXT PRIMARY KEY, price TEXT NOT NULL)")
        }
    }
}
