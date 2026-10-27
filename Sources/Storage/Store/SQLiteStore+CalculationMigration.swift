import GRDB

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
