import Core
import Foundation
import GRDB
import Hub
import Storage

@MainActor
public final class OutboxStore: OutboxPort {
    private let access: any AccessPort
    private let database: SQLiteStore
    private let events: Broadcast<MailboxEvent>
    private var items: [OutboxItem]
    private var unsaved: Set<OutboxItem.ID> = []
    private var unremoved: Set<OutboxItem.ID> = []

    public init(access: any AccessPort, database: SQLiteStore, events: Broadcast<MailboxEvent>) {
        self.access = access
        self.database = database
        self.events = events
        items = Self.load(database)
        _ = try? database.write { db in
            try db.execute(sql: "DELETE FROM mail_outbox WHERE state = 'sent'")
        }
    }

    public var outbox: [OutboxItem] { items }

    public func saveDraft(_ inlet: Inlet.ID, _ draft: Draft, replacing draftID: String?) async throws(HubFailure) -> String {
        try await perform(inlet) { try await $0.saveDraft(draft, replacing: draftID) }
    }

    public func loadDraft(_ inlet: Inlet.ID, messageID: String) async throws(HubFailure) -> StoredDraft {
        try await perform(inlet) { try await $0.fetchDraft(messageID: messageID) }
    }

    public func deleteDraft(_ inlet: Inlet.ID, draftID: String) async throws(HubFailure) {
        try await perform(inlet) { try await $0.deleteDraft(id: draftID) }
    }

    public func send(_ inlet: Inlet.ID, _ draft: Draft) async -> SendOutcome {
        await submit(OutboxItem(inlet: inlet, draft: draft))
    }

    public func sendDraft(_ inlet: Inlet.ID, draftID: String, _ draft: Draft) async -> SendOutcome {
        await submit(OutboxItem(inlet: inlet, draft: draft, draftID: draftID))
    }

    public func resend(_ id: OutboxItem.ID, _ draft: Draft, draftID: String?) async -> SendOutcome? {
        guard let index = items.firstIndex(where: { $0.id == id }), case .failed = items[index].state else { return nil }
        let old = items[index]
        items[index] = OutboxItem(id: id, inlet: old.inlet, draft: draft, messageID: old.messageID,
                                  draftID: draftID ?? old.draftID, state: .waiting, attempts: old.attempts)
        await retry(id, byUser: true)
        return items.contains { $0.id == id } ? .queued(id) : .sent
    }

    public func revise(_ id: OutboxItem.ID, _ draft: Draft) {
        guard let index = items.firstIndex(where: { $0.id == id }), items[index].state == .waiting else { return }
        let old = items[index]
        items[index] = OutboxItem(id: id, inlet: old.inlet, draft: draft, messageID: old.messageID, draftID: old.draftID,
                                  state: .waiting, attempts: old.attempts)
        persist(id)
    }

    func pass(_ inlet: Inlet.ID) async {
        flush()
        for item in items where item.state == .waiting && item.inlet == inlet {
            await retry(item.id)
        }
    }

    func forget(_ inlet: Inlet.ID) -> Bool {
        let before = items.count
        items.removeAll { $0.inlet == inlet }
        return items.count != before
    }

    private func perform<T>(_ inlet: Inlet.ID, _ work: (any MailTransportPort) async throws -> T) async throws(HubFailure) -> T {
        let transport = try access.port((any MailTransportPort).self, for: inlet)
        do {
            return try await work(transport)
        } catch {
            throw DeliveryEngine.hubFailure(error, inlet: inlet, access: access)
        }
    }

    private func submit(_ queued: OutboxItem) async -> SendOutcome {
        var item = queued
        switch await DeliveryEngine.deliver(&item, verify: false, byUser: false, access: access) {
        case .sent:
            return .sent
        case .transient:
            store(item)
            return .queued(item.id)
        case .rejected(let hint):
            var failed = item
            failed.startSending()
            failed.fail(hint)
            store(failed)
            return .queued(item.id)
        }
    }

    private func retry(_ id: OutboxItem.ID, byUser: Bool = false) async {
        guard let index = items.firstIndex(where: { $0.id == id }), items[index].state == .waiting else { return }
        items[index].startSending()
        var item = items[index]
        events.emit(.outboxChanged)
        let result = await DeliveryEngine.deliver(&item, verify: true, byUser: byUser, access: access)
        guard let current = items.firstIndex(where: { $0.id == id }) else { return }
        items[current].draftID = item.draftID
        switch result {
        case .sent:
            items.remove(at: current)
            unsaved.remove(id)
            finish(id)
        case .transient:
            items[current].wait()
            persist(id)
        case .rejected(let hint):
            items[current].fail(hint)
            persist(id)
        }
        events.emit(.outboxChanged)
    }

    private func store(_ item: OutboxItem) {
        items.append(item)
        persist(item.id)
        events.emit(.outboxChanged)
    }

    private func flush() {
        for id in unremoved where (try? delete(id)) != nil { unremoved.remove(id) }
        for id in unsaved { persist(id) }
    }

    private func persist(_ id: OutboxItem.ID) {
        guard let item = items.first(where: { $0.id == id }) else {
            unsaved.remove(id)
            return
        }
        do {
            try save(item)
            unsaved.remove(id)
        } catch {
            unsaved.insert(id)
        }
    }

    private func finish(_ id: OutboxItem.ID) {
        do {
            try delete(id)
            unremoved.remove(id)
        } catch {
            unremoved.insert(id)
            _ = try? database.write { db in
                try db.execute(sql: "UPDATE mail_outbox SET state = 'sent' WHERE id = ?", arguments: [id.uuidString])
            }
        }
    }

    private func save(_ item: OutboxItem) throws {
        let draft = try JSONEncoder().encode(item.draft)
        var name = "waiting"
        var hint: Data?
        if case .failed(let value) = item.state {
            name = "failed"
            hint = try JSONEncoder().encode(value)
        }
        let id = item.id.uuidString
        let inlet = item.inlet
        let attempts = item.attempts
        let draftID = item.draftID
        let messageID = item.messageID
        let state = name
        let hintData = hint
        try database.write { db in
            let position = try Int.fetchOne(db, sql: "SELECT position FROM mail_outbox WHERE id = ?", arguments: [id])
                ?? ((try Int.fetchOne(db, sql: "SELECT MAX(position) FROM mail_outbox") ?? -1) + 1)
            try db.execute(sql: "INSERT OR REPLACE INTO mail_outbox (id, inlet, draft, state, hint, attempts, position, draftID, messageID) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                           arguments: [id, inlet, draft, state, hintData, attempts, position, draftID, messageID])
        }
    }

    private func delete(_ id: OutboxItem.ID) throws {
        try database.write { db in
            try db.execute(sql: "DELETE FROM mail_outbox WHERE id = ?", arguments: [id.uuidString])
        }
    }

    private static func load(_ database: SQLiteStore) -> [OutboxItem] {
        (try? database.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM mail_outbox WHERE state != 'sent' ORDER BY position").compactMap(item)
        }) ?? []
    }

    nonisolated private static func item(_ row: Row) -> OutboxItem? {
        guard let id = UUID(uuidString: row["id"]),
              let draft = try? JSONDecoder().decode(Draft.self, from: row["draft"] as Data) else { return nil }
        var state = OutboxState.waiting
        if (row["state"] as String) == "failed" {
            let hint = (row["hint"] as Data?).flatMap { try? JSONDecoder().decode(Hint.self, from: $0) }
            state = .failed(hint ?? Hint(text: MessageTextKey.failed.rawValue))
        }
        let stored: String = row["messageID"]
        return OutboxItem(id: id, inlet: row["inlet"], draft: draft,
                          messageID: stored.isEmpty ? UUID().uuidString.lowercased() : stored,
                          draftID: row["draftID"], state: state, attempts: row["attempts"])
    }
}
