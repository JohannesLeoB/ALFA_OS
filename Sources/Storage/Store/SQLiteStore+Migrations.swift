import GRDB

extension SQLiteStore {
    static func migrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("hub") { db in
            try db.execute(sql: "CREATE TABLE inlet (id TEXT PRIMARY KEY, json BLOB NOT NULL)")
            try db.execute(sql: """
                CREATE TABLE key_slot (inlet TEXT NOT NULL, name TEXT NOT NULL, PRIMARY KEY (inlet, name))
                """)
            try db.execute(sql: """
                CREATE TABLE inlet_report (
                    seq INTEGER PRIMARY KEY AUTOINCREMENT, inlet TEXT NOT NULL, at REAL NOT NULL, json BLOB NOT NULL)
                """)
            try db.execute(sql: "CREATE INDEX inlet_report_inlet ON inlet_report (inlet, seq)")
            try db.execute(sql: "CREATE TABLE setting (key TEXT PRIMARY KEY, value BLOB NOT NULL)")
            try db.execute(sql: """
                CREATE TABLE cost_day (
                    inlet TEXT NOT NULL, capability TEXT NOT NULL, day INTEGER NOT NULL,
                    calls INTEGER NOT NULL DEFAULT 0, bytes INTEGER NOT NULL DEFAULT 0, tokens INTEGER NOT NULL DEFAULT 0,
                    PRIMARY KEY (inlet, capability, day))
                """)
        }
        migrator.registerMigration("mail") { db in
            try db.execute(sql: """
                CREATE TABLE mail_folder (
                    inlet TEXT NOT NULL, id TEXT NOT NULL, name TEXT NOT NULL, role TEXT NOT NULL, position INTEGER NOT NULL,
                    PRIMARY KEY (inlet, id))
                """)
            try db.execute(sql: """
                CREATE TABLE mail_message (
                    inlet TEXT NOT NULL, folder TEXT NOT NULL, id TEXT NOT NULL, position INTEGER NOT NULL,
                    thread TEXT NOT NULL, subject TEXT NOT NULL, sender TEXT NOT NULL, fromRaw TEXT NOT NULL,
                    toRaw TEXT NOT NULL, ccRaw TEXT NOT NULL, snippet TEXT NOT NULL, receivedAt REAL,
                    flags TEXT NOT NULL, seen INTEGER NOT NULL, folderIDs TEXT NOT NULL, attachmentCount INTEGER NOT NULL,
                    messageIDHeader TEXT NOT NULL DEFAULT '', attachments BLOB,
                    PRIMARY KEY (inlet, folder, id))
                """)
            try db.execute(sql: """
                CREATE TABLE mail_sync (
                    inlet TEXT NOT NULL, folder TEXT NOT NULL, at REAL NOT NULL, PRIMARY KEY (inlet, folder))
                """)
            try db.execute(sql: """
                CREATE TABLE mail_outbox (
                    id TEXT PRIMARY KEY, inlet TEXT NOT NULL, draft BLOB NOT NULL, state TEXT NOT NULL,
                    hint BLOB, attempts INTEGER NOT NULL, position INTEGER NOT NULL, draftID TEXT,
                    messageID TEXT NOT NULL DEFAULT '')
                """)
        }
        migrator.registerMigration("audit") { db in
            try db.create(table: "auditEntries") { t in
                t.primaryKey("id", .text)
                t.column("timestamp", .double).notNull()
                t.column("actorUserID", .text).notNull()
                t.column("projectID", .text).notNull().indexed()
                t.column("action", .text).notNull()
                t.column("summary", .text).notNull()
                t.column("source", .text)
                t.column("idempotencyKey", .text)
            }
            try db.execute(sql: """
                CREATE UNIQUE INDEX idx_auditEntries_idempotencyKey
                ON auditEntries(idempotencyKey)
                WHERE idempotencyKey IS NOT NULL
                """)
            try db.create(table: "integrationLog") { t in
                t.primaryKey("id", .text)
                t.column("timestamp", .double).notNull().indexed()
                t.column("integrationID", .text).notNull().indexed()
                t.column("actorUserID", .text).notNull()
                t.column("action", .text).notNull()
                t.column("recordsRead", .integer).notNull().defaults(to: 0)
                t.column("recordsWritten", .integer).notNull().defaults(to: 0)
                t.column("httpStatus", .integer)
                t.column("errorMessage", .text)
                t.column("durationMs", .integer).notNull().defaults(to: 0)
                t.column("summary", .text).notNull()
            }
        }
        migrator.registerMigration("assistant") { db in
            try db.create(table: "chatMessages") { t in
                t.primaryKey("id", .text)
                t.column("threadScopeKey", .text).notNull().indexed()
                t.column("role", .text).notNull()
                t.column("blocksJSON", .blob).notNull()
                t.column("statusJSON", .blob).notNull()
                t.column("sequence", .integer).notNull()
                t.column("createdAt", .double).notNull()
                t.column("userID", .text)
            }
            try db.execute(sql: "CREATE INDEX idx_chatMessages_userID_scope ON chatMessages(userID, threadScopeKey)")
            try db.create(table: "chatMemorySummaries") { t in
                t.column("userID", .text).notNull()
                t.column("scopeKey", .text).notNull()
                t.column("summaryText", .text).notNull()
                t.column("coveredThroughMessageID", .text).notNull()
                t.column("updatedAt", .double).notNull()
                t.primaryKey(["userID", "scopeKey"])
            }
            try db.create(table: "assistantNotes") { t in
                t.primaryKey("id", .text)
                t.column("body", .text).notNull()
                t.column("createdAt", .double).notNull()
                t.column("updatedAt", .double).notNull().indexed()
                t.column("projectID", .text).indexed()
                t.column("color", .text)
                t.column("userID", .text).indexed()
            }
            try db.create(table: "assistantTasks") { t in
                t.primaryKey("id", .text)
                t.column("title", .text).notNull()
                t.column("done", .boolean).notNull().defaults(to: false)
                t.column("dueDate", .double)
                t.column("createdAt", .double).notNull()
                t.column("updatedAt", .double).notNull().indexed()
                t.column("projectID", .text).indexed()
                t.column("userID", .text).indexed()
                t.column("alarmActive", .boolean).notNull().defaults(to: false)
            }
            try db.create(table: "assistantJournal") { t in
                t.primaryKey("id", .text)
                t.column("timestamp", .double).notNull()
                t.column("projectID", .text)
                t.column("kind", .text).notNull()
                t.column("text", .text).notNull()
            }
            try db.create(table: "privacyPreferences") { t in
                t.primaryKey("id", .text)
                t.column("shareMail", .boolean).notNull().defaults(to: true)
                t.column("shareCalendar", .boolean).notNull().defaults(to: true)
                t.column("shareContacts", .boolean).notNull().defaults(to: true)
                t.column("shareDrive", .boolean).notNull().defaults(to: true)
                t.column("shareClickUp", .boolean).notNull().defaults(to: true)
                t.column("shareNotes", .boolean).notNull().defaults(to: true)
                t.column("shareTasks", .boolean).notNull().defaults(to: true)
                t.column("shareCatalogCalculation", .boolean).notNull().defaults(to: true)
                t.column("shareStudioKnowledge", .boolean).notNull().defaults(to: true)
                t.column("shareChat", .boolean).notNull().defaults(to: true)
                t.column("shareClockodo", .boolean).notNull().defaults(to: true)
                t.column("assistantDisabled", .boolean).notNull().defaults(to: false)
                t.column("updatedAt", .double).notNull()
            }
        }
        migrator.registerMigration("project") { db in
            try db.create(table: "samples") { t in
                t.primaryKey("id", .text)
                t.column("projectNumber", .text).notNull().indexed()
                t.column("status", .text).notNull()
                t.column("updatedAt", .double).notNull()
                t.column("json", .text).notNull()
            }
        }
        migrator.registerMigration("catalog") { db in
            try db.create(table: "articleCatalog") { t in
                t.primaryKey("id", .text)
                t.column("articleNumber", .text).notNull().indexed()
                t.column("manufacturer", .text)
                t.column("category", .text).indexed()
                t.column("searchText", .text).notNull()
                t.column("itemJSON", .text).notNull()
            }
            try db.create(virtualTable: "articleCatalogFTS", using: FTS5()) { t in
                t.synchronize(withTable: "articleCatalog")
                t.column("searchText")
            }
            try db.create(table: "articleCatalogSync") { t in
                t.column("id", .integer).primaryKey().check { $0 == 1 }
                t.column("lastSyncedISO", .text)
            }
        }
        migrator.registerMigration("clockodo") { db in
            try db.create(table: "bookedRows") { t in
                t.primaryKey("rowID", .text)
                t.column("clockodoEntryID", .text).notNull()
                t.column("bookedAt", .double).notNull()
                t.column("userID", .text).notNull().indexed()
            }
        }
        registerCalculation(in: &migrator)
        migrator.registerMigration("sevdesk") { db in
            try db.execute(sql: """
                CREATE TABLE sevdeskReceipts (
                    seq INTEGER PRIMARY KEY AUTOINCREMENT, orderID TEXT NOT NULL UNIQUE, json BLOB NOT NULL)
                """)
        }
        migrator.registerMigration("mailMirror") { db in
            try db.execute(sql: """
                CREATE TABLE mail_cursor (
                    inlet TEXT NOT NULL, key TEXT NOT NULL, value TEXT NOT NULL, PRIMARY KEY (inlet, key))
                """)
            try db.execute(sql: """
                CREATE INDEX mail_message_order ON mail_message (inlet, folder, receivedAt DESC, id DESC)
                """)
        }
        migrator.registerMigration("mailDraft") { db in
            try db.execute(sql: """
                CREATE TABLE mail_draft (
                    id TEXT PRIMARY KEY, inlet TEXT NOT NULL, draft BLOB NOT NULL, remoteID TEXT, mirrorID TEXT,
                    updatedAt REAL NOT NULL)
                """)
        }
        return migrator
    }
}
