import Foundation
import GRDB

public final class LearningDatabase: Sendable {
    public static let schemaVersion = 7

    private let queue: DatabaseQueue

    public let fileURL: URL?

    public init(url: URL) throws {
        self.fileURL = url
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var config = Configuration()
        config.label = "mykilo-learning"
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode = WAL")
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }
        let queue = try DatabaseQueue(path: url.path, configuration: config)
        self.queue = queue

        try Self.backupBeforePendingMigration(queue: queue, fileURL: url)
        try Self.makeMigrator().migrate(queue)
        try recordMetadata()
    }

    public static func inMemory() throws -> LearningDatabase {
        try LearningDatabase(inMemoryQueue: DatabaseQueue())
    }

    private init(inMemoryQueue: DatabaseQueue) throws {
        self.fileURL = nil
        self.queue = inMemoryQueue
        try Self.makeMigrator().migrate(inMemoryQueue)
        try recordMetadata()
    }

    public func read<T>(_ block: (Database) throws -> T) throws -> T {
        try queue.read(block)
    }

    @discardableResult
    public func write<T>(_ block: (Database) throws -> T) throws -> T {
        try queue.write(block)
    }

    private static func makeMigrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_learning_review") { db in
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
                t.column("message", .text).notNull()
            }
            try db.create(table: "review_actions") { t in
                t.autoIncrementedPrimaryKey("pk")
                t.column("recordID", .text).notNull()
                t.column("createdAt", .text).notNull()
                t.column("candidateID", .text).notNull().indexed()
                t.column("kind", .text).notNull()
                t.column("note", .text).notNull()
                t.column("correctedPrice", .text)
                t.column("supersededBy", .text)
            }

            try db.create(table: "learning_metadata") { t in
                t.primaryKey("schluessel", .text)
                t.column("wert", .text).notNull()
            }

            try db.create(table: "learning_import_log") { t in
                t.autoIncrementedPrimaryKey("pk")
                t.column("sourceFile", .text).notNull()
                t.column("fingerprint", .text).notNull().unique()
                t.column("recordCount", .integer).notNull()
                t.column("importedAt", .text).notNull()
            }
        }

        migrator.registerMigration("v2_document_imports") { db in
            try db.create(table: "document_imports") { t in
                t.autoIncrementedPrimaryKey("pk")
                t.column("recordID", .text).notNull()
                t.column("fileName", .text).notNull()
                t.column("sha256", .text).notNull().indexed()
                t.column("sizeBytes", .integer).notNull()
                t.column("isDuplicate", .boolean).notNull()
                t.column("duplicateOf", .text)
                t.column("archivedPath", .text)
                t.column("importedAt", .text).notNull()
                t.column("note", .text).notNull()
            }
        }

        migrator.registerMigration("v3_airtable_offer_sync") { db in
            try db.create(table: "airtable_offer_sync") { t in
                t.autoIncrementedPrimaryKey("pk")
                t.column("recordID", .text).notNull()
                t.column("airtableRecordID", .text).notNull().unique()
                t.column("offerKind", .text).notNull()      
                t.column("nettoEur", .text).notNull()        
                t.column("offerStatus", .text).notNull()
                t.column("partner", .text).notNull()
                t.column("docSHA256", .text)                 
                t.column("importedAt", .text).notNull()
                t.column("reviewActionID", .text)            
                t.column("syncStatus", .text).notNull().defaults(to: "imported")
            }
        }

        migrator.registerMigration("v4_offer_date") { db in
            try db.alter(table: "airtable_offer_sync") { t in
                t.add(column: "offerDate", .text)   
            }
        }

        migrator.registerMigration("v5_pdf_extracted_positions") { db in
            try db.create(table: "pdf_extracted_positions") { t in
                t.autoIncrementedPrimaryKey("pk")
                t.column("recordID", .text).notNull().unique(onConflict: .ignore)
                t.column("sourceFile", .text).notNull()
                t.column("pageNumber", .integer).notNull()
                t.column("titel", .text).notNull()
                t.column("componentType", .text).notNull()
                t.column("netPrice", .text).notNull()          
                t.column("unit", .text).notNull()
                t.column("menge", .double).notNull()
                t.column("confidence", .double).notNull()
                t.column("extractedAt", .text).notNull()
            }
        }

        migrator.registerMigration("v6_korpus_calibration") { db in

            try db.create(table: "korpus_session_snapshots") { t in
                t.autoIncrementedPrimaryKey("pk")
                t.column("recordID", .text).notNull().indexed()
                t.column("sessionID", .text).notNull().unique()
                t.column("snapshotJSON", .text).notNull()   
                t.column("createdAt", .text).notNull()
            }
            try db.create(table: "korpus_adjustments") { t in
                t.autoIncrementedPrimaryKey("pk")
                t.column("recordID", .text).notNull().indexed()
                t.column("sessionID", .text).notNull().indexed()
                t.column("createdAt", .text).notNull()
                t.column("schluessel", .text).notNull().indexed()   
                t.column("modellWert", .double).notNull()
                t.column("beobachteterWert", .double).notNull()
                t.column("reason", .text).notNull()
                t.column("note", .text).notNull()
                t.column("status", .text).notNull()
            }
            try db.create(table: "korpus_calibration_candidates") { t in
                t.autoIncrementedPrimaryKey("pk")
                t.column("recordID", .text).notNull().indexed()
                t.column("createdAt", .text).notNull()
                t.column("schluessel", .text).notNull()
                t.column("sampleCount", .integer).notNull()
                t.column("weightedPercentDelta", .double).notNull()
                t.column("aktuellerWert", .double).notNull()
                t.column("vorgeschlagenerWert", .double).notNull()
                t.column("adjustmentIDs", .text).notNull()
                t.column("status", .text).notNull()
                t.column("note", .text).notNull()
            }
            try db.create(table: "korpus_kalibrier_promotions") { t in
                t.autoIncrementedPrimaryKey("pk")
                t.column("recordID", .text).notNull().indexed()
                t.column("candidateID", .text).notNull()
                t.column("createdAt", .text).notNull()
                t.column("schluessel", .text).notNull()
                t.column("alterWert", .double).notNull()
                t.column("neuerWert", .double).notNull()
                t.column("sampleCount", .integer).notNull()
                t.column("airtableGeschrieben", .boolean).notNull()
                t.column("airtableFehler", .text)
            }
        }

        migrator.registerMigration("v7_record_column_names") { db in
            try renameColumns(db, [
                ("learning_metadata", "schluessel", "key"),
                ("learning_metadata", "wert", "value"),
                ("pdf_extracted_positions", "titel", "title"),
                ("pdf_extracted_positions", "menge", "quantity"),
            ])
        }

        return migrator
    }

    public func appliedMigrations() throws -> [String] {
        try read { db in Array(try Self.makeMigrator().appliedMigrations(db)) }
    }

    private func recordMetadata() throws {
        try write { db in
            try db.execute(
                sql: "INSERT OR IGNORE INTO learning_metadata(key, value) VALUES (?, ?)",
                arguments: ["created_at", LearningCodec.string(from: Date())]
            )
            try db.execute(
                sql: "INSERT OR REPLACE INTO learning_metadata(key, value) VALUES (?, ?)",
                arguments: ["schema_version", String(Self.schemaVersion)]
            )
        }
    }

    public func metadata(_ key: String) throws -> String? {
        try read { db in
            try String.fetchOne(db, sql: "SELECT value FROM learning_metadata WHERE key = ?", arguments: [key])
        }
    }

    public func setMetadata(_ key: String, _ value: String) throws {
        try write { db in
            try db.execute(
                sql: "INSERT OR REPLACE INTO learning_metadata(key, value) VALUES (?, ?)",
                arguments: [key, value]
            )
        }
    }

    public func backup(to destination: URL) throws {
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let target = try DatabaseQueue(path: destination.path)
        try queue.backup(to: target)
    }

    public func integrityCheckPassed() throws -> Bool {
        try read { db in
            let result = try String.fetchOne(db, sql: "PRAGMA integrity_check")
            return result == "ok"
        }
    }

    public func tableExists(_ name: String) throws -> Bool {
        try read { try $0.tableExists(name) }
    }

    private static func backupBeforePendingMigration(queue: DatabaseQueue, fileURL: URL) throws {
        let hasSchema = try queue.read { db in
            try db.tableExists("learning_metadata")
        }
        guard hasSchema else { return }
        let migrator = makeMigrator()
        let pending = try queue.read { db in
            try migrator.hasCompletedMigrations(db) == false
        }
        guard pending else { return }

        try queue.writeWithoutTransaction { db in
            try db.execute(sql: "PRAGMA wal_checkpoint(TRUNCATE)")
        }
        let backupDir = fileURL.deletingLastPathComponent().appendingPathComponent("Backups", isDirectory: true)
        try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
        let stamp = LearningCodec.fileStamp(from: Date())
        let backupURL = backupDir.appendingPathComponent("learning-premigration-\(stamp).sqlite")
        if !FileManager.default.fileExists(atPath: backupURL.path) {
            let target = try DatabaseQueue(path: backupURL.path)
            try queue.backup(to: target)
        }
    }
}
