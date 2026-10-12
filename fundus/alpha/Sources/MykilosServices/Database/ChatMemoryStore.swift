import Foundation
import GRDB
import MykilosKit

struct ChatMemorySummaryRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "chatMemorySummaries"

    var userID: String
    var scopeKey: String
    var summaryText: String
    var coveredThroughMessageID: String
    var updatedAt: Double

    enum Columns {
        static let userID = Column(CodingKeys.userID)
        static let scopeKey = Column(CodingKeys.scopeKey)
    }
}

@MainActor
public final class ChatMemoryStore {
    public private(set) var saveState: SaveState = .idle

    private let db: GRDBDatabase
    private let userID: String?
    private var cache: [String: ChatMemorySummary] = [:]
    private var loadedScopes: Set<String> = []

    public init(db: GRDBDatabase, userID: String? = CurrentUserContext.current) {
        self.db = db
        self.userID = userID
    }

    private var effectiveUserID: String {
        userID ?? CurrentUserContext.chatMemoryFallbackScope
    }

    private func cacheKey(_ scopeKey: String) -> String {
        "\(effectiveUserID)::\(scopeKey)"
    }

    public func summary(for scope: ChatScope) throws -> ChatMemorySummary? {
        let domainKey = scope.rawKey
        let key = cacheKey(domainKey)
        if loadedScopes.contains(key) == false {
            let aktiveUserID = effectiveUserID
            let record = try db.read { dbConn in
                try ChatMemorySummaryRecord.fetchOne(dbConn, key: ["userID": aktiveUserID, "scopeKey": domainKey])
            }
            if let record {
                cache[key] = ChatMemorySummary(
                    scopeKey: domainKey,
                    summaryText: record.summaryText,
                    coveredThroughMessageID: record.coveredThroughMessageID,
                    updatedAt: Date(timeIntervalSince1970: record.updatedAt)
                )
            } else {
                cache[key] = nil
            }
            loadedScopes.insert(key)
        }
        return cache[key]
    }

    public func save(_ summary: ChatMemorySummary) throws {
        saveState = .saving
        do {
            let record = ChatMemorySummaryRecord(
                userID: effectiveUserID,
                scopeKey: summary.scopeKey,
                summaryText: summary.summaryText,
                coveredThroughMessageID: summary.coveredThroughMessageID,
                updatedAt: summary.updatedAt.timeIntervalSince1970
            )
            try db.write { dbConn in
                try record.save(dbConn)
            }
            let key = cacheKey(summary.scopeKey)
            cache[key] = summary
            loadedScopes.insert(key)
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }
}
