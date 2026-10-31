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

public enum DatabaseStore {
    static let fileName = "alfa.sqlite"

    public static func directory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent(AppIdentity.name, isDirectory: true)
    }

    public static func size(in directory: URL? = nil) -> Int? {
        let folder = directory ?? Self.directory()
        let attributes = try? FileManager.default.attributesOfItem(atPath: folder.appendingPathComponent(fileName).path)
        return (attributes?[.size] as? NSNumber)?.intValue
    }

    public static func open(in directory: URL? = nil) throws -> SQLiteStore {
        let folder = directory ?? Self.directory()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return try SQLiteStore(path: folder.appendingPathComponent(fileName).path)
    }
}

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
        migrator.registerMigration("mailBody") { db in
            try db.execute(sql: """
                CREATE TABLE mail_body (
                    inlet TEXT NOT NULL, id TEXT NOT NULL, text TEXT, html TEXT, images BLOB NOT NULL, attachments BLOB NOT NULL,
                    PRIMARY KEY (inlet, id))
                """)
            try db.execute(sql: "CREATE INDEX mail_message_id ON mail_message (inlet, id)")
        }
        migrator.registerMigration("mailReplyTo") { db in
            try db.execute(sql: "ALTER TABLE mail_message ADD COLUMN replyToRaw TEXT NOT NULL DEFAULT ''")
        }
        registerUsage(in: &migrator)
        migrator.registerMigration("mailPop") { db in
            try db.execute(sql: """
                CREATE TABLE mail_pop (
                    inlet TEXT NOT NULL, uid TEXT NOT NULL, folder TEXT NOT NULL, head BLOB NOT NULL, snippet TEXT NOT NULL,
                    attachments BLOB NOT NULL, raw BLOB NOT NULL, seen INTEGER NOT NULL, flagged INTEGER NOT NULL,
                    hidden INTEGER NOT NULL, onServer INTEGER NOT NULL, receivedAt REAL NOT NULL, fetchedAt REAL NOT NULL,
                    PRIMARY KEY (inlet, uid))
                """)
        }
        migrator.registerMigration("mailAttachmentFile") { db in
            try db.execute(sql: """
                CREATE TABLE mail_attachment_file (
                    inlet TEXT NOT NULL, message TEXT NOT NULL, attachment TEXT NOT NULL, path TEXT NOT NULL, size INTEGER NOT NULL,
                    receivedAt REAL, storedAt REAL NOT NULL, PRIMARY KEY (inlet, message, attachment))
                """)
        }
        migrator.registerMigration("mailBcc") { db in
            try db.execute(sql: "ALTER TABLE mail_message ADD COLUMN bccRaw TEXT NOT NULL DEFAULT ''")
        }
        migrator.registerMigration("mailLater") { db in
            try db.execute(sql: "ALTER TABLE mail_outbox ADD COLUMN sendAt REAL")
            try db.execute(sql: "ALTER TABLE mail_outbox ADD COLUMN mirrorID TEXT")
        }
        migrator.registerMigration("mailList") { db in
            try db.execute(sql: "ALTER TABLE mail_body ADD COLUMN unsubscribe BLOB")
        }
        return migrator
    }
}

extension SQLiteStore {
    static func registerCalculation(in migrator: inout DatabaseMigrator) {
        migrator.registerMigration("calculation") { db in
            try db.create(table: "estimate_sessions") { t in
                t.autoIncrementedPrimaryKey("pk")
                t.column("recordID", .text).notNull().indexed()
                t.column("createdAt", .text).notNull()
                t.column("requestText", .text).notNull()
                t.column("baseLowNet", .text).notNull()
                t.column("baseMidNet", .text).notNull()
                t.column("baseHighNet", .text).notNull()
                t.column("laborValueNet", .text).notNull()
                t.column("evidenceIDs", .text).notNull()
                t.column("status", .text).notNull()
            }
            try db.create(table: "estimate_session_components") { t in
                t.autoIncrementedPrimaryKey("pk")
                t.column("recordID", .text).notNull().indexed()
                t.column("sessionID", .text).notNull().indexed()
                t.column("componentIndex", .integer).notNull()
                t.column("componentClass", .text).notNull()
                t.column("componentType", .text).notNull()
                t.column("adjustmentTarget", .text).notNull()
                t.column("baseLowNet", .text).notNull()
                t.column("baseMidNet", .text).notNull()
                t.column("baseHighNet", .text).notNull()
                t.column("evidenceIDs", .text).notNull()
            }
            try db.create(table: "estimate_adjustments") { t in
                t.autoIncrementedPrimaryKey("pk")
                t.column("recordID", .text).notNull().indexed()
                t.column("sessionID", .text).notNull().indexed()
                t.column("createdAt", .text).notNull()
                t.column("percentDelta", .double).notNull()
                t.column("euroDelta", .text)
                t.column("adjustedMidNet", .text).notNull()
                t.column("reason", .text).notNull()
                t.column("target", .text).notNull()
                t.column("status", .text).notNull()
                t.column("note", .text).notNull()
            }
            try db.create(table: "estimate_adjustment_component_targets") { t in
                t.autoIncrementedPrimaryKey("pk")
                t.column("recordID", .text).notNull().indexed()
                t.column("adjustmentID", .text).notNull().indexed()
                t.column("sessionComponentID", .text)
                t.column("target", .text).notNull()
                t.column("percentDelta", .double).notNull()
                t.column("status", .text).notNull()
            }
            try db.create(table: "calibration_factor_candidates") { t in
                t.autoIncrementedPrimaryKey("pk")
                t.column("recordID", .text).notNull().indexed()
                t.column("createdAt", .text).notNull()
                t.column("reason", .text).notNull()
                t.column("target", .text).notNull()
                t.column("sampleCount", .integer).notNull()
                t.column("weightedPercentDelta", .double).notNull()
                t.column("multiplier", .text).notNull()
                t.column("adjustmentIDs", .text).notNull()
                t.column("status", .text).notNull()
                t.column("note", .text).notNull()
            }
            try db.create(table: "active_calibration_factors") { t in
                t.autoIncrementedPrimaryKey("pk")
                t.column("recordID", .text).notNull().indexed()
                t.column("candidateID", .text).notNull()
                t.column("createdAt", .text).notNull()
                t.column("reason", .text).notNull()
                t.column("target", .text).notNull()
                t.column("multiplier", .text).notNull()
                t.column("weightedPercentDelta", .double).notNull()
                t.column("sampleCount", .integer).notNull()
                t.column("status", .text).notNull()
            }
            try db.create(table: "learning_audit_log") { t in
                t.autoIncrementedPrimaryKey("pk")
                t.column("recordID", .text).notNull()
                t.column("createdAt", .text).notNull()
                t.column("entityID", .text).notNull().indexed()
                t.column("entityTable", .text).notNull()
                t.column("action", .text).notNull()
                t.column("detail", .text).notNull()
            }
            try db.create(table: "review_actions") { t in
                t.autoIncrementedPrimaryKey("pk")
                t.column("recordID", .text).notNull()
                t.column("createdAt", .text).notNull()
                t.column("candidateID", .text).notNull().indexed()
                t.column("kind", .text).notNull()
                t.column("note", .text).notNull()
            }
            try db.create(table: "carcass_session_snapshots") { t in
                t.autoIncrementedPrimaryKey("pk")
                t.column("recordID", .text).notNull().indexed()
                t.column("sessionID", .text).notNull().unique()
                t.column("snapshotJSON", .text).notNull()
                t.column("createdAt", .text).notNull()
            }
            try db.create(table: "carcass_adjustments") { t in
                t.autoIncrementedPrimaryKey("pk")
                t.column("recordID", .text).notNull().indexed()
                t.column("sessionID", .text).notNull().indexed()
                t.column("createdAt", .text).notNull()
                t.column("key", .text).notNull().indexed()
                t.column("modelValue", .double).notNull()
                t.column("observedValue", .double).notNull()
                t.column("reason", .text).notNull()
                t.column("note", .text).notNull()
                t.column("status", .text).notNull()
            }
            try db.create(table: "carcass_calibration_candidates") { t in
                t.autoIncrementedPrimaryKey("pk")
                t.column("recordID", .text).notNull().indexed()
                t.column("createdAt", .text).notNull()
                t.column("key", .text).notNull()
                t.column("sampleCount", .integer).notNull()
                t.column("weightedPercentDelta", .double).notNull()
                t.column("currentValue", .double).notNull()
                t.column("proposedValue", .double).notNull()
                t.column("adjustmentIDs", .text).notNull()
                t.column("status", .text).notNull()
                t.column("note", .text).notNull()
            }
            try db.create(table: "supplier_offer_sync") { t in
                t.autoIncrementedPrimaryKey("pk")
                t.column("recordID", .text).notNull()
                t.column("sourceRecordID", .text).notNull().unique()
                t.column("offerKind", .text).notNull()
                t.column("netEur", .text).notNull()
                t.column("offerStatus", .text).notNull()
                t.column("partner", .text).notNull()
                t.column("importedAt", .text).notNull()
                t.column("offerDate", .text)
            }
            try db.create(table: "pdf_extracted_positions") { t in
                t.autoIncrementedPrimaryKey("pk")
                t.column("recordID", .text).notNull().unique(onConflict: .ignore)
                t.column("sourceFile", .text).notNull()
                t.column("pageNumber", .integer).notNull()
                t.column("title", .text).notNull()
                t.column("componentType", .text).notNull()
                t.column("netPrice", .text).notNull()
                t.column("unit", .text).notNull()
                t.column("quantity", .double).notNull()
                t.column("confidence", .double).notNull()
                t.column("extractedAt", .text).notNull()
            }
        }
    }
}

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
