import Foundation
import GRDB

public enum AuditAction: String, Sendable {
    case estimateAdjusted
    case calibrationPromoted
}

public struct AuditEntry: Sendable {
    let id: UUID
    let timestamp: Date
    let actorUserID: String
    public let projectID: String
    let action: AuditAction
    public let summary: String

    public init(id: UUID = UUID(), timestamp: Date = Date(), actorUserID: String,
                projectID: String, action: AuditAction, summary: String) {
        self.id = id
        self.timestamp = timestamp
        self.actorUserID = actorUserID
        self.projectID = projectID
        self.action = action
        self.summary = summary
    }
}

private struct AuditRecord: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "auditEntries" }

    var id: String
    var timestamp: Double
    var actorUserID: String
    var projectID: String
    var action: String
    var summary: String

    init(_ entry: AuditEntry) {
        id = entry.id.uuidString
        timestamp = entry.timestamp.timeIntervalSince1970
        actorUserID = entry.actorUserID
        projectID = entry.projectID
        action = entry.action.rawValue
        summary = entry.summary
    }

    var entry: AuditEntry? {
        guard let id = UUID(uuidString: id), let action = AuditAction(rawValue: action) else { return nil }
        return AuditEntry(id: id, timestamp: Date(timeIntervalSince1970: timestamp), actorUserID: actorUserID,
                          projectID: projectID, action: action, summary: summary)
    }
}

@MainActor
public final class AuditStore {
    public private(set) var entries: [AuditEntry] = []

    private let database: SQLiteStore

    public init(database: SQLiteStore) {
        self.database = database
    }

    public func load() throws {
        let records = try database.read { db in
            try AuditRecord.order(Column("timestamp").desc).fetchAll(db)
        }
        entries = records.compactMap(\.entry)
    }

    public func append(_ entry: AuditEntry) throws {
        try database.write { db in
            try AuditRecord(entry).insert(db)
        }
        entries.insert(entry, at: 0)
    }
}

public enum IntegrationAction: String, Sendable {
    case success = "SUCCESS"
    case error = "ERROR"
}

public struct IntegrationEntry: Sendable {
    public let integrationID: String
    public let actorUserID: String
    public let action: IntegrationAction
    public let errorMessage: String?
    public let summary: String
}

private struct IntegrationLogRecord: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "integrationLog" }

    var id = UUID().uuidString
    var timestamp = Date().timeIntervalSince1970
    var integrationID: String
    var actorUserID: String
    var action: String
    var errorMessage: String?
    var summary: String

    init(_ entry: IntegrationEntry) {
        integrationID = entry.integrationID
        actorUserID = entry.actorUserID
        action = entry.action.rawValue
        errorMessage = entry.errorMessage
        summary = entry.summary
    }
}

private let integrationLogLimit = 500

@MainActor
public final class IntegrationLogStore {
    public private(set) var entries: [IntegrationEntry] = []

    private let database: SQLiteStore

    public init(database: SQLiteStore) {
        self.database = database
    }

    public func log(integrationID: String, actorUserID: String, action: IntegrationAction, errorMessage: String? = nil, summary: String) {
        let entry = IntegrationEntry(integrationID: integrationID, actorUserID: actorUserID, action: action,
                                     errorMessage: errorMessage, summary: summary)
        try? database.write { db in
            try IntegrationLogRecord(entry).insert(db)
        }
        entries.insert(entry, at: 0)
        if entries.count > integrationLogLimit { entries.removeLast(entries.count - integrationLogLimit) }
    }
}
