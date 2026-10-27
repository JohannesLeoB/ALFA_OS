import Foundation
import GRDB

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
