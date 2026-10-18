import Foundation
import Observation
import GRDB
import AlfaKit

public enum ChatStoreError: Error, Equatable {
    case corruptRecord(String)
}

@MainActor
@Observable
public final class ChatStore {
    public private(set) var saveState: SaveState = .idle

    private let db: GRDBDatabase

    private let userID: String?

    private var byScope: [String: [ChatMessage]] = [:]
    private var loadedScopes: Set<String> = []

    public init(db: GRDBDatabase, userID: String? = CurrentUserContext.current) {
        self.db = db
        self.userID = userID
    }

    public func messages(for scope: ChatScope) -> [ChatMessage] {
        byScope[scope.rawKey] ?? []
    }

    public func loadIfNeeded(_ scope: ChatScope) throws {
        let key = scope.rawKey
        guard loadedScopes.contains(key) == false else { return }
        let records = try db.read { dbConn in
            try ChatMessageRecord
                .filter(ChatMessageRecord.Columns.threadScopeKey == key)
                .filter(ChatMessageRecord.Columns.userID == userID)
                .order(ChatMessageRecord.Columns.sequence)
                .fetchAll(dbConn)
        }

        byScope[key] = records.map { $0.toDomainResilient() }
        loadedScopes.insert(key)
    }

    public func append(_ message: ChatMessage, to scope: ChatScope) throws {
        try loadIfNeeded(scope)
        let key = scope.rawKey
        var list = byScope[key] ?? []
        let sequence = list.count
        saveState = .saving
        do {
            let record = try ChatMessageRecord(from: message, scopeKey: key, sequence: sequence, userID: userID)
            try db.write { dbConn in
                try record.insert(dbConn)
            }
            list.append(message)
            byScope[key] = list
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }

    public func updateStreamingText(id: UUID, text: String, in scope: ChatScope) {
        let key = scope.rawKey
        guard var list = byScope[key],
              let index = list.firstIndex(where: { $0.id == id }) else { return }
        var updated = list[index]
        var blocks = updated.blocks
        if let ti = blocks.firstIndex(where: { if case .text = $0 { true } else { false } }) {
            blocks[ti] = .text(text)
        } else {
            blocks.insert(.text(text), at: 0)
        }
        updated.blocks = blocks
        list[index] = updated
        byScope[key] = list
    }

    public func updateStreamingActivities(id: UUID, activities: [ChatContentBlock], in scope: ChatScope) {
        let key = scope.rawKey
        guard var list = byScope[key],
              let index = list.firstIndex(where: { $0.id == id }) else { return }
        var updated = list[index]
        let text = updated.blocks.first { if case .text = $0 { true } else { false } } ?? .text("")
        updated.blocks = activities + [text]
        list[index] = updated
        byScope[key] = list
    }

    public func updateAssistantTurn(
        id: UUID,
        blocks: [ChatContentBlock],
        status: ChatTurnStatus,
        in scope: ChatScope
    ) throws {
        let key = scope.rawKey
        guard var list = byScope[key], let index = list.firstIndex(where: { $0.id == id }) else { return }
        var updated = list[index]
        updated.blocks = blocks
        updated.status = status
        saveState = .saving
        do {
            let record = try ChatMessageRecord(from: updated, scopeKey: key, sequence: index, userID: userID)
            try db.write { dbConn in
                try record.update(dbConn)
            }
            list[index] = updated
            byScope[key] = list
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }

    public func clear(_ scope: ChatScope) throws {
        let key = scope.rawKey
        saveState = .saving
        do {
            try db.write { dbConn in
                try ChatMessageRecord
                    .filter(ChatMessageRecord.Columns.threadScopeKey == key)
                    .filter(ChatMessageRecord.Columns.userID == userID)
                    .deleteAll(dbConn)
            }
            byScope[key] = []
            loadedScopes.insert(key)
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }
}
