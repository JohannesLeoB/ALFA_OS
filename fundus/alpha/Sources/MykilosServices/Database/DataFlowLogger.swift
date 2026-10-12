import Foundation
import Observation
import GRDB
import MykilosKit

public enum DataFlowAction: String, Codable, Sendable {
    case start   = "START"
    case success = "SUCCESS"
    case error   = "ERROR"
}

public struct DataFlowEntry: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let integrationID: String
    public let actorUserID: String
    public let action: DataFlowAction
    public let recordsRead: Int
    public let recordsWritten: Int
    public let httpStatus: Int?
    public let errorMessage: String?
    public let durationMs: Int
    public let summary: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        integrationID: String,
        actorUserID: String,
        action: DataFlowAction,
        recordsRead: Int = 0,
        recordsWritten: Int = 0,
        httpStatus: Int? = nil,
        errorMessage: String? = nil,
        durationMs: Int = 0,
        summary: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.integrationID = integrationID
        self.actorUserID = actorUserID
        self.action = action
        self.recordsRead = recordsRead
        self.recordsWritten = recordsWritten
        self.httpStatus = httpStatus
        self.errorMessage = errorMessage
        self.durationMs = durationMs
        self.summary = summary
    }
}

struct DataFlowLogRecord: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "dataFlowLog" }

    var id: String
    var timestamp: Double
    var integrationID: String
    var actorUserID: String
    var action: String
    var recordsRead: Int
    var recordsWritten: Int
    var httpStatus: Int?
    var errorMessage: String?
    var durationMs: Int
    var summary: String

    init(from entry: DataFlowEntry) {
        self.id             = entry.id.uuidString
        self.timestamp      = entry.timestamp.timeIntervalSince1970
        self.integrationID  = entry.integrationID
        self.actorUserID    = entry.actorUserID
        self.action         = entry.action.rawValue
        self.recordsRead    = entry.recordsRead
        self.recordsWritten = entry.recordsWritten
        self.httpStatus     = entry.httpStatus
        self.errorMessage   = entry.errorMessage
        self.durationMs     = entry.durationMs
        self.summary        = entry.summary
    }

    var toDomain: DataFlowEntry? {
        guard let id = UUID(uuidString: id),
              let action = DataFlowAction(rawValue: action) else { return nil }
        return DataFlowEntry(
            id: id,
            timestamp: Date(timeIntervalSince1970: timestamp),
            integrationID: integrationID,
            actorUserID: actorUserID,
            action: action,
            recordsRead: recordsRead,
            recordsWritten: recordsWritten,
            httpStatus: httpStatus,
            errorMessage: errorMessage,
            durationMs: durationMs,
            summary: summary
        )
    }
}

@MainActor
@Observable
public final class DataFlowLogger {
    public private(set) var entries: [DataFlowEntry] = []
    public private(set) var saveState: SaveState = .idle

    private let db: GRDBDatabase
    private let airtable: (any AirtableRecordCreating)?
    private let baseID: String

    public init(
        db: GRDBDatabase,
        airtable: (any AirtableRecordCreating)? = nil,
        baseID: String = CompanySetup.valueOrEmpty("airtable.base.data_flow")
    ) {
        self.db = db
        self.airtable = airtable
        self.baseID = baseID
    }

    public func load(ownerActorUserID: String? = nil) throws {
        do {
            let records = try db.read { dbConn in
                var request = DataFlowLogRecord.order(Column("timestamp").desc)
                if let ownerActorUserID {
                    request = request.filter(Column("actorUserID") == ownerActorUserID)
                }
                return try request.limit(500).fetchAll(dbConn)
            }
            entries = records.compactMap(\.toDomain)
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }

    public func append(_ entry: DataFlowEntry) throws {
        saveState = .saving
        do {
            try db.write { dbConn in
                try DataFlowLogRecord(from: entry).insert(dbConn)
            }
            entries.insert(entry, at: 0)
            if entries.count > 500 { entries.removeLast(entries.count - 500) }
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
        mirrorToAirtable(entry)
    }

    public func log(
        integrationID: String,
        actorUserID: String,
        action: DataFlowAction,
        recordsRead: Int = 0,
        recordsWritten: Int = 0,
        httpStatus: Int? = nil,
        errorMessage: String? = nil,
        durationMs: Int = 0,
        summary: String
    ) {
        let entry = DataFlowEntry(
            integrationID: integrationID, actorUserID: actorUserID, action: action,
            recordsRead: recordsRead, recordsWritten: recordsWritten,
            httpStatus: httpStatus, errorMessage: errorMessage,
            durationMs: durationMs, summary: summary
        )
        try? append(entry)
    }

    private func mirrorToAirtable(_ entry: DataFlowEntry) {
        guard let airtable else { return }
        let baseID = self.baseID
        let fields: [String: AirtableFieldValue] = [
            "Timestamp": .string(ISO8601DateFormatter().string(from: entry.timestamp)),
            "Integrations-ID": .string(entry.integrationID),
            "Nutzer-ID": .string(entry.actorUserID),
            "Aktion": .string(entry.action.rawValue),
            "Records-Gelesen": .number(Double(entry.recordsRead)),
            "Records-Geschrieben": .number(Double(entry.recordsWritten)),
            "HTTP-Status": entry.httpStatus.map { .number(Double($0)) } ?? .null,
            "Fehler-Nachricht": entry.errorMessage.map { .string($0) } ?? .null,
            "Dauer-Ms": .number(Double(entry.durationMs)),
            "Changelog": .string(entry.summary)
        ]
        Task {
            _ = try? await airtable.createRecord(baseID: baseID, table: "Datenstrom-Log", fields: fields)
        }
    }
}
