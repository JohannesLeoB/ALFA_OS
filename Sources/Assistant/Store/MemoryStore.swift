import Foundation
import GRDB
import Storage

private struct StoredMemorySummary: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "chatMemorySummaries" }

    var userID: String
    var scopeKey: String
    var summaryText: String
    var coveredThroughMessageID: String
    var updatedAt: Double
}

@MainActor
public final class MemoryStore {
    static let fallbackOwner = "local"

    private let database: SQLiteStore
    private let owner: String
    private var cache: [String: MemorySummary?] = [:]

    public init(database: SQLiteStore, userID: String?) {
        self.database = database
        self.owner = userID ?? Self.fallbackOwner
    }

    public func summary(for scope: ConversationScope) throws -> MemorySummary? {
        let scopeKey = scope.rawKey
        if let cached = cache[scopeKey] { return cached }
        let owner = owner
        let record = try database.read { db in
            try StoredMemorySummary.fetchOne(db, key: ["userID": owner, "scopeKey": scopeKey])
        }
        let summary = record.map {
            MemorySummary(scopeKey: scopeKey, summaryText: $0.summaryText,
                          coveredThroughMessageID: $0.coveredThroughMessageID,
                          updatedAt: Date(timeIntervalSince1970: $0.updatedAt))
        }
        cache[scopeKey] = .some(summary)
        return summary
    }

    public func save(_ summary: MemorySummary) throws {
        let record = StoredMemorySummary(
            userID: owner, scopeKey: summary.scopeKey, summaryText: summary.summaryText,
            coveredThroughMessageID: summary.coveredThroughMessageID, updatedAt: summary.updatedAt.timeIntervalSince1970)
        try database.write { db in try record.save(db) }
        cache[summary.scopeKey] = .some(summary)
    }
}
