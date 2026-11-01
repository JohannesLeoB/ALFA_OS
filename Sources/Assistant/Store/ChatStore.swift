import Foundation
import GRDB
import Observation
import Storage

private struct StoredMessage: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "chatMessages" }

    var id: String
    var threadScopeKey: String
    var role: String
    var blocksJSON: Data
    var statusJSON: Data
    var sequence: Int
    var createdAt: Double
    var userID: String?

    init(_ message: Message, scopeKey: String, sequence: Int, userID: String?) throws {
        id = message.id.uuidString
        threadScopeKey = scopeKey
        role = message.role.rawValue
        blocksJSON = try JSONEncoder().encode(message.blocks)
        statusJSON = try JSONEncoder().encode(message.status)
        self.sequence = sequence
        createdAt = message.createdAt.timeIntervalSince1970
        self.userID = userID
    }

    var message: Message {
        let uuid = UUID(uuidString: id) ?? UUID()
        let parsedRole = MessageRole(rawValue: role) ?? .assistant
        let created = Date(timeIntervalSince1970: createdAt)
        if let blocks = try? JSONDecoder().decode([ContentBlock].self, from: blocksJSON),
           let status = try? JSONDecoder().decode(TurnStatus.self, from: statusJSON) {
            return Message(id: uuid, role: parsedRole, blocks: blocks, status: status, createdAt: created)
        }
        return Message(id: uuid, role: parsedRole, blocks: [.unreadable], status: .complete, createdAt: created)
    }
}

@MainActor @Observable
public final class ChatStore: ChatPort {
    private(set) var saveState: SaveState = .idle

    @ObservationIgnored private let database: SQLiteStore
    @ObservationIgnored private let userID: String?
    private var byScope: [String: [Message]] = [:]
    @ObservationIgnored private var loadedScopes: Set<String> = []

    public init(database: SQLiteStore, userID: String?) {
        self.database = database
        self.userID = userID
    }

    public func messages(for scope: ConversationScope) -> [Message] {
        byScope[scope.rawKey] ?? []
    }

    public func loadIfNeeded(_ scope: ConversationScope) throws {
        let key = scope.rawKey
        guard loadedScopes.contains(key) == false else { return }
        let owner = userID
        let records = try database.read { db in
            try StoredMessage
                .filter(Column("threadScopeKey") == key)
                .filter(Column("userID") == owner)
                .order(Column("sequence"))
                .fetchAll(db)
        }
        byScope[key] = records.map(\.message)
        loadedScopes.insert(key)
    }

    public func append(_ message: Message, to scope: ConversationScope) throws {
        try loadIfNeeded(scope)
        let key = scope.rawKey
        var list = byScope[key] ?? []
        saveState = .saving
        do {
            let record = try StoredMessage(message, scopeKey: key, sequence: list.count, userID: userID)
            try database.write { db in try record.insert(db) }
            list.append(message)
            byScope[key] = list
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }

    public func updateStreamingText(id: UUID, text: String, in scope: ConversationScope) {
        let key = scope.rawKey
        guard var list = byScope[key], let index = list.firstIndex(where: { $0.id == id }) else { return }
        var blocks = list[index].blocks
        if let textIndex = blocks.firstIndex(where: { if case .text = $0 { true } else { false } }) {
            blocks[textIndex] = .text(text)
        } else {
            blocks.insert(.text(text), at: 0)
        }
        list[index].blocks = blocks
        byScope[key] = list
    }

    public func updateStreamingActivities(id: UUID, activities: [ContentBlock], in scope: ConversationScope) {
        let key = scope.rawKey
        guard var list = byScope[key], let index = list.firstIndex(where: { $0.id == id }) else { return }
        let text = list[index].blocks.first { if case .text = $0 { true } else { false } } ?? .text("")
        list[index].blocks = activities + [text]
        byScope[key] = list
    }

    public func updateAssistantTurn(id: UUID, blocks: [ContentBlock], status: TurnStatus,
                             in scope: ConversationScope) throws {
        let key = scope.rawKey
        guard var list = byScope[key], let index = list.firstIndex(where: { $0.id == id }) else { return }
        var updated = list[index]
        updated.blocks = blocks
        updated.status = status
        saveState = .saving
        do {
            let record = try StoredMessage(updated, scopeKey: key, sequence: index, userID: userID)
            try database.write { db in try record.update(db) }
            list[index] = updated
            byScope[key] = list
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }

    public func remove(_ ids: Set<UUID>, from scope: ConversationScope) throws {
        try loadIfNeeded(scope)
        let key = scope.rawKey
        let owner = userID
        let names = ids.map(\.uuidString)
        let remaining = (byScope[key] ?? []).filter { ids.contains($0.id) == false }
        saveState = .saving
        do {
            try database.write { db in
                _ = try StoredMessage
                    .filter(names.contains(Column("id")))
                    .filter(Column("threadScopeKey") == key)
                    .filter(Column("userID") == owner)
                    .deleteAll(db)
                for (index, message) in remaining.enumerated() {
                    try db.execute(sql: "UPDATE chatMessages SET sequence = ? WHERE id = ?",
                                   arguments: [index, message.id.uuidString])
                }
            }
            byScope[key] = remaining
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }

    public func clear(_ scope: ConversationScope) throws {
        let key = scope.rawKey
        let owner = userID
        saveState = .saving
        do {
            try database.write { db in
                _ = try StoredMessage
                    .filter(Column("threadScopeKey") == key)
                    .filter(Column("userID") == owner)
                    .deleteAll(db)
            }
            byScope[key] = []
            loadedScopes.insert(key)
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }

    public func attachmentPaths() throws -> Set<String> {
        let stored = try database.read { db in
            try Data.fetchAll(db, sql: "SELECT blocksJSON FROM chatMessages")
        }
        var paths = Set<String>()
        for data in stored {
            for block in (try? JSONDecoder().decode([ContentBlock].self, from: data)) ?? [] {
                switch block {
                case .image(let ref), .document(let ref): paths.insert(ref.relativePath)
                default: break
                }
            }
        }
        return paths
    }
}

private struct StoredMemorySummary: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "chatMemorySummaries" }

    var userID: String
    var scopeKey: String
    var summaryText: String
    var coveredThroughMessageID: String
    var updatedAt: Double
}

@MainActor
public final class MemoryStore: MemoryPort {
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
