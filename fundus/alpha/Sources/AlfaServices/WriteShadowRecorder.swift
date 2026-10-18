import Foundation
import Observation
import GRDB
import AlfaKit

public enum WriteShadowAction: String, Codable, Sendable { case create, update }
public enum WriteShadowSystem: String, Codable, Sendable { case airtable, drive, clockodo, clickUp }
public enum WriteShadowResult: String, Codable, Sendable { case ok, error }

public struct WriteShadowEntry: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let actorUserID: String
    public let action: WriteShadowAction
    public let targetSystem: WriteShadowSystem
    public let targetBase: String?
    public let targetTable: String?
    public let targetRecordID: String?
    public let payloadJSON: String
    public let previousValueJSON: String?
    public let mode: ProvisioningMode
    public let result: WriteShadowResult
    public let errorMessage: String?

    public init(
        id: UUID = UUID(), timestamp: Date = Date(), actorUserID: String,
        action: WriteShadowAction, targetSystem: WriteShadowSystem,
        targetBase: String? = nil, targetTable: String? = nil, targetRecordID: String? = nil,
        payloadJSON: String, previousValueJSON: String? = nil,
        mode: ProvisioningMode, result: WriteShadowResult, errorMessage: String? = nil
    ) {
        self.id = id; self.timestamp = timestamp; self.actorUserID = actorUserID
        self.action = action; self.targetSystem = targetSystem
        self.targetBase = targetBase; self.targetTable = targetTable; self.targetRecordID = targetRecordID
        self.payloadJSON = payloadJSON; self.previousValueJSON = previousValueJSON
        self.mode = mode; self.result = result; self.errorMessage = errorMessage
    }
}

struct WriteShadowRecord: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "writeShadowLog" }

    var id: String
    var timestamp: Double
    var actorUserID: String
    var action: String
    var targetSystem: String
    var targetBase: String?
    var targetTable: String?
    var targetRecordID: String?
    var payloadJSON: String
    var previousValueJSON: String?
    var mode: String
    var result: String
    var errorMessage: String?
    var mirroredToBackupBase: Bool

    init(from entry: WriteShadowEntry, mirrored: Bool) {
        id = entry.id.uuidString
        timestamp = entry.timestamp.timeIntervalSince1970
        actorUserID = entry.actorUserID
        action = entry.action.rawValue
        targetSystem = entry.targetSystem.rawValue
        targetBase = entry.targetBase
        targetTable = entry.targetTable
        targetRecordID = entry.targetRecordID
        payloadJSON = entry.payloadJSON
        previousValueJSON = entry.previousValueJSON
        mode = entry.mode.rawValue
        result = entry.result.rawValue
        errorMessage = entry.errorMessage
        mirroredToBackupBase = mirrored
    }
}

@MainActor
@Observable
public final class WriteShadowRecorder {
    public private(set) var saveState: SaveState = .idle

    private let db: GRDBDatabase
    private let airtable: (any AirtableRecordCreating)?
    private let backupBaseID: String?
    private let dataFlow: DataFlowLogger?

    public init(
        db: GRDBDatabase,
        airtable: (any AirtableRecordCreating)? = nil,
        backupBaseID: String? = nil,
        dataFlow: DataFlowLogger? = nil
    ) {
        self.db = db
        self.airtable = airtable
        self.backupBaseID = backupBaseID
        self.dataFlow = dataFlow
    }

    @discardableResult
    public func recordAirtableWrite(
        action: WriteShadowAction, actorUserID: String, baseID: String, table: String,
        recordID: String?, fields: [String: AirtableFieldValue],
        previousFields: [String: AirtableFieldValue]? = nil,
        mode: ProvisioningMode, result: WriteShadowResult, errorMessage: String? = nil
    ) throws -> WriteShadowEntry {
        let entry = WriteShadowEntry(
            actorUserID: actorUserID, action: action, targetSystem: .airtable,
            targetBase: baseID, targetTable: table, targetRecordID: recordID,
            payloadJSON: Self.jsonString(from: fields),
            previousValueJSON: previousFields.map(Self.jsonString(from:)),
            mode: mode, result: result, errorMessage: errorMessage
        )
        try append(entry)
        return entry
    }

    public func load(limit: Int = 200) throws -> [WriteShadowEntry] {
        try db.read { dbConn in
            try WriteShadowRecord
                .order(Column("timestamp").desc)
                .limit(limit)
                .fetchAll(dbConn)
        }.compactMap(\.toDomain)
    }

    private func append(_ entry: WriteShadowEntry) throws {
        saveState = .saving
        let mirrored = backupBaseID != nil
        do {
            try db.write { dbConn in
                try WriteShadowRecord(from: entry, mirrored: mirrored).insert(dbConn)
            }
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
        if let backupBaseID {
            mirrorToBackupBase(entry, baseID: backupBaseID)
        } else {
            dataFlow?.log(
                integrationID: "WRITE_SHADOW_BACKUP_FEHLT", actorUserID: entry.actorUserID,
                action: .error,
                errorMessage: "mykilOS-Backup-Base noch nicht konfiguriert — Write-Shadow nur lokal (GRDB), kein Airtable-Spiegel",
                summary: "Write-Shadow für \(entry.targetSystem.rawValue)/\(entry.targetTable ?? "?") ohne externe Sicherheitskopie"
            )
        }
    }

    private func mirrorToBackupBase(_ entry: WriteShadowEntry, baseID: String) {
        guard let airtable else { return }
        let fields: [String: AirtableFieldValue] = [
            "Zeitstempel": .string(ISO8601DateFormatter().string(from: entry.timestamp)),
            "Nutzer": .string(entry.actorUserID),
            "Aktion": .string(entry.action.rawValue),
            "Ziel-System": .string(entry.targetSystem.rawValue),
            "Ziel-Base": entry.targetBase.map { .string($0) } ?? .null,
            "Ziel-Tabelle": entry.targetTable.map { .string($0) } ?? .null,
            "Ziel-Record-ID": entry.targetRecordID.map { .string($0) } ?? .null,
            "Payload-JSON": .string(entry.payloadJSON),
            "Vorwert-JSON": entry.previousValueJSON.map { .string($0) } ?? .null,
            "TEST-PROD": .string(entry.mode.rawValue),
            "Ergebnis": .string(entry.result.rawValue)
        ]
        let dataFlow = self.dataFlow
        let actorUserID = entry.actorUserID
        Task {
            do {
                _ = try await airtable.createRecord(baseID: baseID, table: "Write-Shadow-Log", fields: fields)

                dataFlow?.log(
                    integrationID: "WRITE_SHADOW_LOG", actorUserID: actorUserID,
                    action: .success, recordsWritten: 1,
                    summary: "Write-Shadow-Spiegel nach mykilOS-Backup geschrieben (\(entry.targetSystem.rawValue)/\(entry.targetTable ?? "?"))"
                )
            } catch {
                dataFlow?.log(
                    integrationID: "WRITE_SHADOW_BACKUP_FEHLT", actorUserID: actorUserID,
                    action: .error, errorMessage: String(describing: error),
                    summary: "Write-Shadow-Spiegel nach mykilOS-Backup fehlgeschlagen — Tabellenname/Schema prüfen"
                )
            }
        }
    }

    static func jsonString(from fields: [String: AirtableFieldValue]) -> String {
        let plain = fields.mapValues(\.jsonValue)
        guard let data = try? JSONSerialization.data(withJSONObject: plain, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else { return "{}" }
        return string
    }
}

private extension WriteShadowRecord {
    var toDomain: WriteShadowEntry? {
        guard let id = UUID(uuidString: id),
              let action = WriteShadowAction(rawValue: action),
              let targetSystem = WriteShadowSystem(rawValue: targetSystem),
              let mode = ProvisioningMode(rawValue: mode),
              let result = WriteShadowResult(rawValue: result) else { return nil }
        return WriteShadowEntry(
            id: id, timestamp: Date(timeIntervalSince1970: timestamp), actorUserID: actorUserID,
            action: action, targetSystem: targetSystem, targetBase: targetBase, targetTable: targetTable,
            targetRecordID: targetRecordID, payloadJSON: payloadJSON, previousValueJSON: previousValueJSON,
            mode: mode, result: result, errorMessage: errorMessage
        )
    }
}
