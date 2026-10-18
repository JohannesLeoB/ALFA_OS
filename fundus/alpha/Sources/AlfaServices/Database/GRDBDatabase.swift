import Foundation
import GRDB
import AlfaKit

public final class GRDBDatabase: Sendable {
    private let queue: DatabaseQueue

    public init(url: URL) throws {
        var config = Configuration()
        config.label = AppKennung.name
        config.prepareDatabase { db in

            try db.execute(sql: "PRAGMA journal_mode = WAL")
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }
        queue = try DatabaseQueue(path: url.path, configuration: config)
        try runMigrations()
    }

    public static func inMemory() throws -> GRDBDatabase {
        let db = GRDBDatabase(queue: try DatabaseQueue())
        try db.runMigrations()
        return db
    }

    public func read<T: Sendable>(_ block: @Sendable (Database) throws -> T) throws -> T {
        try queue.read(block)
    }

    @discardableResult
    public func write<T: Sendable>(_ block: @Sendable (Database) throws -> T) throws -> T {
        try queue.write(block)
    }

    public func checkpoint() throws {
        try queue.write { db in
            try db.execute(sql: "PRAGMA wal_checkpoint(TRUNCATE)")
        }
    }

    public var dbPath: String { queue.path }

    private func runMigrations() throws {
        try Self.buildMigrator().migrate(queue)
    }

    static func buildMigrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_widgets_notes") { db in

            try db.create(table: "widgetInstances") { t in
                t.primaryKey("id", .text)
                t.column("boardID", .text).notNull().indexed()
                t.column("kind", .text).notNull()
                t.column("size", .text).notNull()
                t.column("position", .integer).notNull()
                t.column("isVisible", .boolean).notNull().defaults(to: true)
                t.column("isPinned", .boolean).notNull().defaults(to: false)
            }

            try db.create(table: "notes") { t in
                t.primaryKey("id", .text)
                t.column("boardID", .text).notNull().indexed()
                t.column("body", .text).notNull()
                t.column("updatedAt", .double).notNull()
            }

            try db.create(table: "auditEntries") { t in
                t.primaryKey("id", .text)
                t.column("timestamp", .double).notNull()
                t.column("actorUserID", .text).notNull()
                t.column("projectID", .text).notNull().indexed()
                t.column("action", .text).notNull()
                t.column("summary", .text).notNull()
            }
        }

        migrator.registerMigration("v2_chat") { db in
            try db.create(table: "chatMessages") { t in
                t.primaryKey("id", .text)
                t.column("threadScopeKey", .text).notNull().indexed()
                t.column("role", .text).notNull()
                t.column("blocksJSON", .blob).notNull()
                t.column("statusJSON", .blob).notNull()
                t.column("sequence", .integer).notNull()
                t.column("createdAt", .double).notNull()
            }
        }

        migrator.registerMigration("v3_profile") { db in
            try db.create(table: "userProfile") { t in
                t.primaryKey("id", .text)
                t.column("displayName", .text).notNull()
                t.column("role", .text).notNull()
                t.column("updatedAt", .double).notNull()
            }
        }

        migrator.registerMigration("v4_reconciled_boards") { db in
            try db.create(table: "reconciledBoards") { t in
                t.primaryKey("boardID", .text)
            }
        }

        migrator.registerMigration("v5_profile_identity") { db in
            try db.alter(table: "userProfile") { t in
                t.add(column: "clockodoUserID", .text)
                t.add(column: "googleDomain", .text)
            }
        }

        migrator.registerMigration("v6_dataflow_log") { db in
            try db.create(table: "dataFlowLog") { t in
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

        migrator.registerMigration("v7_project_favorites") { db in
            try db.create(table: "projectFavorites") { t in
                t.primaryKey("projektNummer", .text)
                t.column("addedAt", .double).notNull()
            }
        }

        migrator.registerMigration("v8_assistant_notes") { db in
            try db.create(table: "assistantNotes") { t in
                t.primaryKey("id", .text)
                t.column("body", .text).notNull()
                t.column("createdAt", .double).notNull()
                t.column("updatedAt", .double).notNull().indexed()
            }
        }

        migrator.registerMigration("v9_assistant_tasks") { db in
            try db.create(table: "assistantTasks") { t in
                t.primaryKey("id", .text)
                t.column("titel", .text).notNull()
                t.column("done", .boolean).notNull().defaults(to: false)
                t.column("dueDate", .double)
                t.column("createdAt", .double).notNull()
                t.column("updatedAt", .double).notNull().indexed()
            }
        }

        migrator.registerMigration("v10_assistant_project_scope") { db in
            try db.alter(table: "assistantNotes") { t in
                t.add(column: "projectID", .text).indexed()
            }
            try db.alter(table: "assistantTasks") { t in
                t.add(column: "projectID", .text).indexed()
            }
        }

        migrator.registerMigration("v11_assistant_note_color") { db in
            try db.alter(table: "assistantNotes") { t in
                t.add(column: "color", .text)
            }
        }

        migrator.registerMigration("v12_write_shadow_log") { db in
            try db.create(table: "writeShadowLog") { t in
                t.primaryKey("id", .text)
                t.column("timestamp", .double).notNull().indexed()
                t.column("actorUserID", .text).notNull()
                t.column("action", .text).notNull()
                t.column("targetSystem", .text).notNull()
                t.column("targetBase", .text)
                t.column("targetTable", .text)
                t.column("targetRecordID", .text)
                t.column("payloadJSON", .text).notNull()
                t.column("previousValueJSON", .text)
                t.column("mode", .text).notNull()
                t.column("result", .text).notNull()
                t.column("errorMessage", .text)
                t.column("mirroredToBackupBase", .boolean).notNull().defaults(to: false)
            }
        }

        migrator.registerMigration("v13_app_settings") { db in
            try db.create(table: "appSettings") { t in
                t.primaryKey("schluessel", .text)
                t.column("wert", .text).notNull()
                t.column("updatedAt", .double).notNull()
            }
        }

        migrator.registerMigration("v14_project_number_bindings") { db in
            try db.create(table: "projectNumberBindings") { t in
                t.primaryKey("businessRecordID", .text)
                t.column("projektNummer", .text).notNull().indexed()
                t.column("confirmedAt", .double).notNull()
                t.column("actorUserID", .text).notNull()
            }
        }

        migrator.registerMigration("v15_time_tracking") { db in
            try db.create(table: "activeTimer") { t in
                t.primaryKey("id", .text)
                t.column("projektNummer", .text).notNull()
                t.column("projektTitel", .text).notNull()
                t.column("kostenstelle", .text).notNull()
                t.column("runSince", .double).notNull()
                t.column("pausedAccumulatedSeconds", .double).notNull().defaults(to: 0)
                t.column("isPaused", .boolean).notNull().defaults(to: false)
                t.column("segmentStartedAt", .double).notNull()
            }
            try db.create(table: "timeSegmentDrafts") { t in
                t.primaryKey("id", .text)
                t.column("projektNummer", .text).notNull().indexed()
                t.column("projektTitel", .text).notNull()
                t.column("kostenstelle", .text).notNull()
                t.column("startedAt", .double).notNull()
                t.column("endedAt", .double).notNull()
                t.column("seconds", .double).notNull()
            }
            try db.create(table: "timeSegments") { t in
                t.primaryKey("id", .text)
                t.column("projektNummer", .text).notNull().indexed()
                t.column("projektTitel", .text).notNull()
                t.column("kostenstelle", .text).notNull()
                t.column("startedAt", .double).notNull()
                t.column("endedAt", .double).notNull()
                t.column("seconds", .double).notNull()
                t.column("bookedAt", .double).notNull().indexed()
            }
            try db.create(table: "projectZielkontingente") { t in
                t.primaryKey("projektNummer", .text)
                t.column("zielStunden", .double).notNull()
                t.column("herkunft", .text).notNull()
                t.column("updatedAt", .double).notNull()
            }
        }

        migrator.registerMigration("v16_nomenklatur") { db in
            try db.create(table: "vergebeneNummern") { t in
                t.primaryKey("appFormat", .text)
                t.column("jahr", .integer).notNull().indexed()
                t.column("laufendeNummer", .integer).notNull()
                t.column("status", .text).notNull()
                t.column("quelle", .text)
                t.column("updatedAt", .double).notNull()
            }
            try db.create(table: "nomenklaturConfig") { t in
                t.primaryKey("schluessel", .text)
                t.column("wert", .text).notNull()
                t.column("updatedAt", .double).notNull()
            }
            try db.create(table: "ordnerKonnektoren") { t in
                t.primaryKey("slot", .text)
                t.column("ordnername", .text).notNull()
                t.column("relativerPfad", .text).notNull()
                t.column("schemaVersion", .integer).notNull()
                t.column("updatedAt", .double).notNull()
            }
            try db.create(table: "projektKostenstellen") { t in
                t.primaryKey("projektNummer", .text)
                t.column("namenJSON", .text).notNull()
                t.column("updatedAt", .double).notNull()
            }
        }

        migrator.registerMigration("v17_provisioning") { db in
            try db.create(table: "provisioningLedger") { t in
                t.primaryKey("idempotenzSchluessel", .text)
                t.column("projektnummer", .text).notNull().indexed()
                t.column("kdnr", .text).notNull().indexed()
                t.column("status", .text).notNull()
                t.column("erledigteSchritteJSON", .text).notNull()
                t.column("driveProjektOrdnerID", .text)
                t.column("driveUnterordnerJSON", .text).notNull()
                t.column("airtableRecordID", .text)
                t.column("letzterFehler", .text)
                t.column("updatedAt", .double).notNull()
            }
            try db.create(table: "clickUpRouting") { t in
                t.primaryKey("routingID", .text)
                t.column("ebene", .text).notNull()
                t.column("richtung", .text).notNull()
                t.column("appObjekt", .text).notNull()
                t.column("clickUpObjekt", .text).notNull()
                t.column("trigger", .text).notNull()
                t.column("userScope", .text).notNull()
                t.column("frequenz", .text).notNull()
                t.column("noGo", .text)
                t.column("clickUpRef", .text)
                t.column("aktiv", .boolean).notNull().defaults(to: false)
                t.column("optin", .boolean).notNull().defaults(to: false)
                t.column("updatedAt", .double).notNull()
            }
        }

        migrator.registerMigration("v18_chat_memory_summary") { db in
            try db.create(table: "chatMemorySummaries") { t in
                t.primaryKey("scopeKey", .text)
                t.column("summaryText", .text).notNull()
                t.column("coveredThroughMessageID", .text).notNull()
                t.column("updatedAt", .double).notNull()
            }
        }

        migrator.registerMigration("v19_provisioning_clickup") { db in
            try db.alter(table: "provisioningLedger") { t in
                t.add(column: "clickUpListID", .text)
            }
        }

        migrator.registerMigration("v20_project_lifecycle_stage") { db in
            try db.create(table: "projectLifecycleStage") { t in
                t.primaryKey("projektNummer", .text)
                t.column("stageIndex", .integer).notNull()
                t.column("setAt", .double).notNull()
            }
        }

        migrator.registerMigration("v21_workbasket") { db in
            try db.create(table: "workBaskets") { t in
                t.primaryKey("id", .text)
                t.column("projektNummer", .text).notNull().indexed()
                t.column("inhaltsArt", .text).notNull()
                t.column("version", .integer).notNull().defaults(to: 1)
                t.column("statusJSON", .text).notNull()
                t.column("erstellt", .double).notNull()
            }
            try db.create(table: "workBasketPicks") { t in
                t.primaryKey("id", .text)
                t.column("basketID", .text).notNull().indexed()
                    .references("workBaskets", column: "id", onDelete: .cascade)
                t.column("position", .integer).notNull()
                t.column("matrix", .text).notNull()
                t.column("objektID", .text).notNull()
                t.column("snapshotJSON", .text).notNull()
                t.column("inhaltJSON", .text).notNull()
            }
        }

        migrator.registerMigration("v22_user_identity") { db in
            try db.alter(table: "userProfile") { t in
                t.add(column: "userID", .text)
            }
        }

        migrator.registerMigration("v23_audit_checkin") { db in
            try db.alter(table: "auditEntries") { t in
                t.add(column: "quelle", .text)
                t.add(column: "idempotenzKey", .text)
            }
            try db.execute(sql: """
                CREATE UNIQUE INDEX IF NOT EXISTS idx_auditEntries_idempotenzKey
                ON auditEntries(idempotenzKey)
                WHERE idempotenzKey IS NOT NULL
                """)
        }

        migrator.registerMigration("v24_resident_identity") { db in
            try db.create(table: "residentIdentity") { t in
                t.column("googleEmail", .text).primaryKey()
                t.column("userID", .text).notNull()
                t.column("displayName", .text)
                t.column("clockodoUserID", .text)
                t.column("clockodoEntwurfsTabelle", .text)
                t.column("clickUpMemberID", .text)
                t.column("airtableRecordID", .text)
                t.column("updatedAt", .double).notNull()
            }
        }

        migrator.registerMigration("v25_chat_user_isolation") { db in
            try db.alter(table: "chatMessages") { t in
                t.add(column: "userID", .text)
            }
            try db.execute(sql: """
                CREATE INDEX IF NOT EXISTS idx_chatMessages_userID_scope
                ON chatMessages(userID, threadScopeKey)
                """)
        }

        migrator.registerMigration("v26_assistant_notes_tasks_isolation") { db in
            try db.alter(table: "assistantNotes") { t in t.add(column: "userID", .text) }
            try db.alter(table: "assistantTasks") { t in t.add(column: "userID", .text) }
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_assistantNotes_userID ON assistantNotes(userID)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_assistantTasks_userID ON assistantTasks(userID)")
        }

        migrator.registerMigration("v27_timer_user_isolation") { db in
            try db.alter(table: "timeSegmentDrafts") { t in t.add(column: "userID", .text) }
            try db.alter(table: "timeSegments") { t in t.add(column: "userID", .text) }
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_timeSegmentDrafts_userID ON timeSegmentDrafts(userID)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_timeSegments_userID ON timeSegments(userID)")
        }

        migrator.registerMigration("v28_profile_personal") { db in
            try db.alter(table: "userProfile") { t in
                t.add(column: "birthDate", .double)
                t.add(column: "phone", .text)
                t.add(column: "department", .text)
                t.add(column: "bio", .text)
            }
        }

        migrator.registerMigration("v29_datenschutz_praeferenzen") { db in
            try db.create(table: "datenschutzPraeferenzen") { t in
                t.primaryKey("id", .text)
                t.column("teileMailMitAssistent", .boolean).notNull().defaults(to: true)
                t.column("teileNotizenMitAssistent", .boolean).notNull().defaults(to: true)
                t.column("teileChatMitAssistent", .boolean).notNull().defaults(to: true)
                t.column("teileClockodoMitAssistent", .boolean).notNull().defaults(to: true)
                t.column("kiKomplettAus", .boolean).notNull().defaults(to: false)
                t.column("updatedAt", .double).notNull()
            }
        }

        migrator.registerMigration("v30_assistant_task_alarm") { db in
            try db.alter(table: "assistantTasks") { t in
                t.add(column: "alarmAktiv", .boolean).notNull().defaults(to: false)
            }
        }

        migrator.registerMigration("v31_assistant_tagebuch") { db in
            try db.create(table: "assistantTagebuch") { t in
                t.primaryKey("id", .text)
                t.column("timestamp", .double).notNull()
                t.column("projectID", .text)
                t.column("art", .text).notNull()
                t.column("text", .text).notNull()
            }
        }

        migrator.registerMigration("v32_clickup_golive_whitelist") { db in
            try db.create(table: "clickUpGoLiveWhitelist") { t in
                t.primaryKey("listID", .text)
                t.column("projektNummer", .text).notNull()
                t.column("freigegebenVon", .text).notNull()
                t.column("freigegebenAm", .double).notNull()
            }
        }

        migrator.registerMigration("v33_drive_folder_cache") { db in
            try db.create(table: "driveFolderCache") { t in
                t.column("folderID", .text).primaryKey()
                t.column("filesJSON", .text).notNull()
                t.column("folderName", .text)
                t.column("fetchedAt", .double).notNull()
            }
        }

        migrator.registerMigration("v34_switchboard") { db in
            try db.create(table: "commercialDraftPackages") { t in
                t.primaryKey("id", .text)
                t.column("packageID", .text).notNull().indexed()
                t.column("revision", .integer).notNull()
                t.column("createdAt", .double).notNull()
                t.column("createdByUserID", .text).notNull()
                t.column("projektID", .text).notNull().indexed()
                t.column("projektCode", .text).notNull()
                t.column("contactID", .text).notNull()
                t.column("processType", .text).notNull()
                t.column("titel", .text).notNull()
                t.column("einleitungsText", .text)
                t.column("schlussText", .text)
                t.column("currency", .text).notNull()
                t.column("steuerKontextID", .text).notNull()
                t.column("expectedNet", .text).notNull()
                t.column("expectedTax", .text).notNull()
                t.column("expectedGross", .text).notNull()
                t.column("payloadSchemaVersion", .integer).notNull()
                t.column("payloadSHA256", .text).notNull()
                t.column("übergabeStatus", .text).notNull()
                t.column("sevdeskOrderID", .text)
                t.column("sevdeskOrderNumber", .text)
                t.column("lastErrorCode", .text)
            }
            try db.execute(sql: """
                CREATE UNIQUE INDEX IF NOT EXISTS idx_commercialDraftPackages_packageID_revision
                ON commercialDraftPackages(packageID, revision)
                """)

            try db.create(table: "commercialDraftPositions") { t in
                t.primaryKey("id", .text)
                t.column("packageRevisionKey", .text).notNull().indexed()
                    .references("commercialDraftPackages", column: "id", onDelete: .cascade)
                t.column("packageID", .text).notNull()
                t.column("positionID", .text).notNull()
                t.column("sequenz", .integer).notNull()
                t.column("kind", .text).notNull()
                t.column("mykilosArtikelID", .text)
                t.column("sevdeskPartID", .text)
                t.column("bezeichnung", .text).notNull()
                t.column("beschreibung", .text)
                t.column("menge", .text).notNull()
                t.column("einheitText", .text).notNull()
                t.column("vkNettoEinzel", .text)
                t.column("steuerKontextID", .text).notNull()
                t.column("mappingState", .text).notNull()
                t.column("positionSHA256", .text).notNull()
            }

            try db.create(table: "integrationCommands") { t in
                t.primaryKey("commandID", .text)
                t.column("packageID", .text).notNull().indexed()
                t.column("revision", .integer).notNull()
                t.column("requestedAction", .text).notNull()
                t.column("approvalToken", .text)
                t.column("idempotencyKey", .text).notNull()
                t.column("expectedPayloadSHA256", .text).notNull()
                t.column("state", .text).notNull()
                t.column("leaseOwner", .text)
                t.column("leaseExpiresAt", .double)
                t.column("attemptCount", .integer).notNull().defaults(to: 0)
                t.column("nextAttemptAt", .double)
                t.column("lastErrorCode", .text)
                t.column("createdAt", .double).notNull()
            }
            try db.execute(sql: """
                CREATE UNIQUE INDEX IF NOT EXISTS idx_integrationCommands_idempotencyKey
                ON integrationCommands(idempotencyKey)
                """)

            try db.create(table: "integrationEvents") { t in
                t.primaryKey("eventID", .text)
                t.column("commandID", .text).notNull().indexed()
                t.column("packageID", .text).notNull().indexed()
                t.column("revision", .integer).notNull()
                t.column("eventType", .text).notNull()
                t.column("previousState", .text)
                t.column("newState", .text).notNull()
                t.column("payloadSHA256", .text).notNull()
                t.column("remoteObjectID", .text)
                t.column("remoteFingerprint", .text)
                t.column("occurredAt", .double).notNull()
                t.column("recordedAt", .double).notNull()
                t.column("workerID", .text)
                t.column("resultSummary", .text)
            }

            try db.create(table: "sevdeskMirrors") { t in
                t.primaryKey("sevdeskOrderID", .text)
                t.column("packageID", .text).notNull().indexed()
                t.column("sevdeskOrderType", .text).notNull()
                t.column("rawStatus", .text).notNull()
                t.column("orderNumber", .text)
                t.column("sumNet", .text)
                t.column("sumTax", .text)
                t.column("sumGross", .text)
                t.column("remoteChangedAt", .double)
                t.column("remoteFingerprint", .text).notNull()
                t.column("syncedAt", .double).notNull()
            }

            try db.create(table: "sevdeskMappings") { t in
                t.primaryKey("id", .text)
                t.column("kind", .text).notNull()
                t.column("mykilosID", .text).notNull()
                t.column("sevdeskID", .text).notNull()
                t.column("verifiedAt", .double).notNull()
                t.column("remoteFingerprint", .text)
            }
            try db.execute(sql: """
                CREATE UNIQUE INDEX IF NOT EXISTS idx_sevdeskMappings_kind_mykilosID
                ON sevdeskMappings(kind, mykilosID)
                """)
        }

        migrator.registerMigration("v35_clickup_team_golive") { db in
            try db.create(table: "clickUpTeamGoLive") { t in
                t.primaryKey("kuerzel", .text)
                t.column("freigegebenVon", .text).notNull()
                t.column("freigegebenAm", .double).notNull()
            }
        }

        migrator.registerMigration("v36_datenschutz_kategorien") { db in
            try db.alter(table: "datenschutzPraeferenzen") { t in
                t.add(column: "teileKalenderMitAssistent", .boolean).notNull().defaults(to: true)
                t.add(column: "teileKontakteMitAssistent", .boolean).notNull().defaults(to: true)
                t.add(column: "teileDriveMitAssistent", .boolean).notNull().defaults(to: true)
                t.add(column: "teileClickUpMitAssistent", .boolean).notNull().defaults(to: true)
                t.add(column: "teileAufgabenMitAssistent", .boolean).notNull().defaults(to: true)
                t.add(column: "teileKatalogKalkulationMitAssistent", .boolean).notNull().defaults(to: true)
                t.add(column: "teileStudioWissenMitAssistent", .boolean).notNull().defaults(to: true)
            }
        }

        migrator.registerMigration("v37_kontakte_lokal") { db in
            try db.create(table: "kontaktLokal") { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull()
                t.column("organisation", .text)
                t.column("email", .text).indexed()
                t.column("telefon", .text)
                t.column("adresse", .text)
                t.column("projekt", .text)
                t.column("kategorie", .text)
                t.column("vorname", .text)
                t.column("nachname", .text)
                t.column("photoURL", .text)

                t.column("herkunft", .text).notNull().defaults(to: "lokal")
                t.column("aktualisiertAm", .double).notNull().defaults(to: 0)
            }
        }

        migrator.registerMigration("v38_kontakte_lokal_composite_key") { db in
            try db.create(table: "kontaktLokal_neu") { t in
                t.column("id", .text).notNull()
                t.column("name", .text).notNull()
                t.column("organisation", .text)
                t.column("email", .text).indexed()
                t.column("telefon", .text)
                t.column("adresse", .text)
                t.column("projekt", .text)
                t.column("kategorie", .text)
                t.column("vorname", .text)
                t.column("nachname", .text)
                t.column("photoURL", .text)
                t.column("herkunft", .text).notNull().defaults(to: "lokal")
                t.column("aktualisiertAm", .double).notNull().defaults(to: 0)
                t.primaryKey(["id", "herkunft"])
            }
            try db.execute(sql: """
                INSERT OR IGNORE INTO kontaktLokal_neu
                SELECT id, name, organisation, email, telefon, adresse, projekt, kategorie,
                       vorname, nachname, photoURL, herkunft, aktualisiertAm
                FROM kontaktLokal
                """)
            try db.drop(table: "kontaktLokal")
            try db.rename(table: "kontaktLokal_neu", to: "kontaktLokal")
        }

        migrator.registerMigration("v39_aufmass_entwuerfe") { db in
            try db.create(table: "aufmassEntwurf") { t in
                t.primaryKey("id", .text)
                t.column("erstelltAm", .double).notNull().indexed()
                t.column("projektNummer", .text)
                t.column("titel", .text).notNull().defaults(to: "")
                t.column("dokumentJSON", .text).notNull()
                t.column("fotoPNG", .blob)
                t.column("bildEndung", .text)
            }
        }

        migrator.registerMigration("v40_chat_memory_summaries_user_id") { db in
            try db.create(table: "chatMemorySummaries_neu") { t in
                t.column("userID", .text)
                t.column("scopeKey", .text).notNull()
                t.column("summaryText", .text).notNull()
                t.column("coveredThroughMessageID", .text).notNull()
                t.column("updatedAt", .double).notNull()
                t.primaryKey(["userID", "scopeKey"])
            }
            try db.execute(sql: """
                INSERT OR IGNORE INTO chatMemorySummaries_neu (userID, scopeKey, summaryText, coveredThroughMessageID, updatedAt)
                SELECT
                    CASE WHEN INSTR(scopeKey, '::') > 0 THEN SUBSTR(scopeKey, 1, INSTR(scopeKey, '::') - 1) ELSE NULL END,
                    CASE WHEN INSTR(scopeKey, '::') > 0 THEN SUBSTR(scopeKey, INSTR(scopeKey, '::') + 2) ELSE scopeKey END,
                    summaryText, coveredThroughMessageID, updatedAt
                FROM chatMemorySummaries
                """)
            try db.drop(table: "chatMemorySummaries")
            try db.rename(table: "chatMemorySummaries_neu", to: "chatMemorySummaries")
        }

        migrator.registerMigration("v41_clickup_task_signal_cache") { db in
            try db.create(table: "clickUpTaskSignalCache") { t in
                t.primaryKey("taskID", .text)
                t.column("listID", .text).notNull().indexed()
                t.column("taskName", .text).notNull()
                t.column("evidenceGrade", .integer)
                t.column("blockerType", .integer)
                t.column("sourceSystem", .integer)
                t.column("financeRelevant", .boolean).notNull().defaults(to: false)
                t.column("reviewRequired", .boolean).notNull().defaults(to: false)
                t.column("changeOrderRelevant", .boolean).notNull().defaults(to: false)
                t.column("driveFolderURL", .text)
                t.column("clientName", .text)
                t.column("mykilosProjectID", .text)
                t.column("projectPhase", .integer)
                t.column("fetchedAt", .double).notNull()
            }
        }

        migrator.registerMigration("v42_clickup_airtable_sync_state") { db in
            try db.create(table: "clickUpAirtableSyncState") { t in
                t.column("projektNummer", .text).notNull()
                t.column("clickUpFeldName", .text).notNull()
                t.column("letzterWert", .text).notNull()
                t.column("syncedAt", .double).notNull()
                t.primaryKey(["projektNummer", "clickUpFeldName"])
            }
        }

        migrator.registerMigration("v43_project_wahrscheinlichkeit") { db in
            try db.create(table: "projectWahrscheinlichkeit") { t in
                t.primaryKey("projektNummer", .text)
                t.column("historieText", .text).notNull()
                t.column("updatedAt", .double).notNull()
            }
        }

        migrator.registerMigration("v44_bestellwesen") { db in
            try db.create(table: "bestellungen") { t in
                t.primaryKey("id", .text)
                t.column("projektNummer", .text).notNull().indexed()
                t.column("status", .text).notNull()
                t.column("aktualisiertAm", .double).notNull()
                t.column("json", .text).notNull()
            }
        }

        migrator.registerMigration("v45_abrechnungswesen") { db in
            try db.create(table: "abrechnungsLeistungen") { t in
                t.primaryKey("id", .text)
                t.column("projektNummer", .text).notNull().indexed()
                t.column("art", .text).notNull()
                t.column("aktualisiertAm", .double).notNull()
                t.column("json", .text).notNull()
            }
        }

        migrator.registerMigration("v46_telefonnotizen") { db in
            try db.create(table: "telefonnotizen") { t in
                t.primaryKey("id", .text)
                t.column("projektNummer", .text).notNull().indexed()
                t.column("datum", .double).notNull()
                t.column("json", .text).notNull()
            }
        }

        migrator.registerMigration("v47_lead_karten") { db in
            try db.create(table: "leadKarten") { t in
                t.primaryKey("projektNummer", .text)
                t.column("taskID", .text).notNull()
                t.column("status", .text).notNull()
                t.column("aktualisiertAm", .double).notNull()
            }
        }

        migrator.registerMigration("v48_lebenszyklus_5_auf_7") { db in
            try db.execute(sql: """
                UPDATE projectLifecycleStage SET stageIndex = CASE stageIndex
                    WHEN 0 THEN 0
                    WHEN 1 THEN 2
                    WHEN 2 THEN 1
                    WHEN 3 THEN 4
                    WHEN 4 THEN 5
                    ELSE stageIndex
                END
                """)
        }

        migrator.registerMigration("v49_bemusterung") { db in
            try db.create(table: "bemusterungen") { t in
                t.primaryKey("id", .text)
                t.column("projektNummer", .text).notNull().indexed()
                t.column("status", .text).notNull()
                t.column("aktualisiertAm", .double).notNull()
                t.column("json", .text).notNull()
            }
        }

        migrator.registerMigration("v50_servicefaelle") { db in
            try db.create(table: "servicefaelle") { t in
                t.primaryKey("id", .text)
                t.column("projektNummer", .text).notNull().indexed()
                t.column("status", .text).notNull()
                t.column("aktualisiertAm", .double).notNull()
                t.column("json", .text).notNull()
            }
        }

        migrator.registerMigration("v51_meilensteine") { db in
            try db.create(table: "meilensteine") { t in
                t.primaryKey("id", .text)
                t.column("projektNummer", .text).notNull().indexed()
                t.column("status", .text).notNull()
                t.column("datum", .double).notNull()
                t.column("aktualisiertAm", .double).notNull()
                t.column("json", .text).notNull()
            }
        }

        migrator.registerMigration("v52_nachfassfaelle") { db in
            try db.create(table: "nachfassfaelle") { t in
                t.primaryKey("id", .text)
                t.column("kundeName", .text).notNull()
                t.column("kundennummer", .text).indexed()
                t.column("status", .text).notNull()
                t.column("naechstesNachfassen", .double)
                t.column("wert", .double)
                t.column("aktualisiertAm", .double).notNull()
                t.column("json", .text).notNull()
            }
        }

        migrator.registerMigration("v53_clockodo_echte_buchungen") { db in
            try db.create(table: "clockodoEchteBuchungen") { t in
                t.primaryKey("zeilenID", .text)
                t.column("clockodoEntryID", .text).notNull()
                t.column("gebuchtAm", .double).notNull()
                t.column("userID", .text).notNull().indexed()
            }
        }

        migrator.registerMigration("v54_skizzen_entwuerfe") { db in
            try db.create(table: "skizzeEntwurf") { t in
                t.primaryKey("id", .text)
                t.column("erstelltAm", .double).notNull().indexed()
                t.column("projektNummer", .text)
                t.column("titel", .text).notNull()
                t.column("dokumentJSON", .text).notNull()
                t.column("fotoPNG", .blob)
                t.column("bildEndung", .text)
            }
        }

        migrator.registerMigration("v55_konfigurator_entwuerfe") { db in
            try db.create(table: "konfigEntwurf") { t in
                t.primaryKey("id", .text)
                t.column("erstelltAm", .double).notNull()
                t.column("geaendertAm", .double).notNull().indexed()
                t.column("projektNummer", .text).notNull().indexed()
                t.column("variantenName", .text).notNull()
                t.column("status", .text).notNull()
                t.column("dokumentJSON", .text).notNull()
            }
        }

        migrator.registerMigration("v56_artikel_katalog") { db in
            try db.create(table: "artikelKatalog") { t in
                t.primaryKey("id", .text)
                t.column("artikelnummer", .text).notNull().indexed()
                t.column("hersteller", .text)
                t.column("kategorie", .text).indexed()
                t.column("suchtext", .text).notNull()
                t.column("itemJSON", .text).notNull()
            }

            try db.create(virtualTable: "artikelKatalogFTS", using: FTS5()) { t in
                t.synchronize(withTable: "artikelKatalog")
                t.column("suchtext")
            }
        }

        migrator.registerMigration("v57_schlagwort_mesh") { db in
            try db.create(table: "schlagwort") { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull()
                t.column("achse", .text).notNull().indexed()
                t.column("quelle", .text).notNull()
                t.column("synonymVon", .text)
            }
            try db.create(table: "artikelSchlagwort") { t in
                t.column("artikelID", .text).notNull().indexed()
                t.column("schlagwortID", .text).notNull()
                    .references("schlagwort", onDelete: .cascade)
                t.column("score", .double).notNull()
                t.column("quelle", .text).notNull()
                t.primaryKey(["artikelID", "schlagwortID"])
            }
        }

        migrator.registerMigration("v58_artikel_sync_marker") { db in
            try db.create(table: "artikelKatalogSync") { t in
                t.column("id", .integer).primaryKey().check { $0 == 1 }
                t.column("zuletztGesynctISO", .text)
            }
        }

        migrator.registerMigration("v59_mail") { db in
            try db.create(table: "mailMessage") { t in
                t.column("id", .text).primaryKey()
                t.column("account", .text).notNull().indexed()
                t.column("threadId", .text).notNull().defaults(to: "")
                t.column("subject", .text).notNull().defaults(to: "")
                t.column("fromName", .text).notNull().defaults(to: "")
                t.column("fromRaw", .text).notNull().defaults(to: "")
                t.column("toRaw", .text).notNull().defaults(to: "")
                t.column("ccRaw", .text).notNull().defaults(to: "")
                t.column("snippet", .text).notNull().defaults(to: "")
                t.column("receivedAt", .double).indexed()
                t.column("labels", .text).notNull().defaults(to: "[]")
                t.column("hasAttachments", .boolean).notNull().defaults(to: false)
                t.column("attachments", .text).notNull().defaults(to: "[]")
                t.column("messageIdHeader", .text).notNull().defaults(to: "")
                t.column("historyId", .text).notNull().defaults(to: "")
                t.column("bodyText", .text)
                t.column("bodyHTML", .text)
                t.column("inlineImages", .text)
                t.column("fetchedAt", .double).notNull().defaults(to: 0)
            }
            try db.create(table: "mailSync") { t in
                t.column("account", .text).primaryKey()
                t.column("historyId", .text).notNull().defaults(to: "")
                t.column("updatedAt", .double).notNull().defaults(to: 0)
            }
            try db.create(virtualTable: "mailFTS", using: FTS5()) { t in
                t.synchronize(withTable: "mailMessage")
                t.tokenizer = .unicode61()
                t.column("subject")
                t.column("fromName")
                t.column("snippet")
                t.column("bodyText")
            }
        }

        migrator.registerMigration("v60_record_column_names") { db in
            try renameColumns(db, [
                ("projectFavorites", "projektNummer", "projectNumber"),
                ("assistantTasks", "titel", "title"),
                ("appSettings", "schluessel", "key"),
                ("appSettings", "wert", "value"),
                ("projectNumberBindings", "projektNummer", "projectNumber"),
                ("nomenklaturConfig", "schluessel", "key"),
                ("nomenklaturConfig", "wert", "value"),
                ("projectLifecycleStage", "projektNummer", "projectNumber"),
                ("clickUpAirtableSyncState", "projektNummer", "projectNumber"),
                ("projectWahrscheinlichkeit", "projektNummer", "projectNumber"),
            ])
        }

        return migrator
    }

    private init(queue: DatabaseQueue) { self.queue = queue }
}
