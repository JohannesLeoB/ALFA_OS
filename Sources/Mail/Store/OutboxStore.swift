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

    public var unsavedCount: Int { unsaved.count }

    public func resave() {
        flush()
        events.emit(.outboxChanged)
    }

    public func saveDraft(_ inlet: Inlet.ID, _ draft: Draft, replacing draftID: String?) async throws(HubFailure) -> SavedDraft {
        let target = MailboxStore.folderID(database, inlet, role: .drafts)
        return try await perform(inlet) { try await $0.saveDraft(draft, replacing: draftID, into: target) }
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
        guard let index = items.firstIndex(where: { $0.id == id }), items[index].state.needsAttention else { return nil }
        let old = items[index]
        items[index] = OutboxItem(id: id, inlet: old.inlet, draft: draft, messageID: old.messageID,
                                  draftID: draftID ?? old.draftID, mirrorID: old.mirrorID, state: .waiting,
                                  attempts: old.attempts)
        await retry(id, byUser: true)
        return items.contains { $0.id == id } ? .queued(id) : .sent
    }

    public func confirm(_ id: OutboxItem.ID) async {
        guard let index = items.firstIndex(where: { $0.id == id }), case .unverified = items[index].state else { return }
        items[index].wait()
        await retry(id, byUser: true, verify: false)
    }

    public func discard(_ id: OutboxItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }), items[index].state != .sending else { return }
        items.remove(at: index)
        unsaved.remove(id)
        do {
            try delete(id)
            unremoved.remove(id)
        } catch {
            unremoved.insert(id)
        }
        events.emit(.outboxChanged)
    }

    public func revise(_ id: OutboxItem.ID, _ draft: Draft) {
        guard let index = items.firstIndex(where: { $0.id == id }), items[index].state == .waiting else { return }
        let old = items[index]
        items[index] = OutboxItem(id: id, inlet: old.inlet, draft: draft, messageID: old.messageID, draftID: old.draftID,
                                  mirrorID: old.mirrorID, state: .waiting, attempts: old.attempts)
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
        let inlet = queued.inlet
        switch await DeliveryEngine.deliver(&item, verify: false, byUser: false, access: access,
                                            folder: { MailboxStore.folderID(self.database, inlet, role: $0) }) {
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
        case .unverified(let hint):
            var unchecked = item
            unchecked.startSending()
            unchecked.unverify(hint)
            store(unchecked)
            return .queued(item.id)
        }
    }

    private func retry(_ id: OutboxItem.ID, byUser: Bool = false, verify: Bool = true) async {
        guard let index = items.firstIndex(where: { $0.id == id }), items[index].state == .waiting else { return }
        items[index].startSending()
        var item = items[index]
        let inlet = item.inlet
        events.emit(.outboxChanged)
        let result = await DeliveryEngine.deliver(&item, verify: verify, byUser: byUser, access: access,
                                                  folder: { MailboxStore.folderID(self.database, inlet, role: $0) })
        guard let current = items.firstIndex(where: { $0.id == id }) else { return }
        items[current].draftID = item.draftID
        items[current].mirrorID = item.mirrorID
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
        case .unverified(let hint):
            items[current].unverify(hint)
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
        switch item.state {
        case .failed(let value):
            name = "failed"
            hint = try JSONEncoder().encode(value)
        case .unverified(let value):
            name = "unverified"
            hint = try JSONEncoder().encode(value)
        case .waiting, .sending:
            break
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
        let name: String = row["state"]
        if name == "failed" || name == "unverified" {
            let hint = (row["hint"] as Data?).flatMap { try? JSONDecoder().decode(Hint.self, from: $0) }
                ?? Hint(text: MessageTextKey.failed.rawValue)
            state = name == "failed" ? .failed(hint) : .unverified(hint)
        }
        let stored: String = row["messageID"]
        return OutboxItem(id: id, inlet: row["inlet"], draft: draft,
                          messageID: stored.isEmpty ? UUID().uuidString.lowercased() : stored,
                          draftID: row["draftID"], state: state, attempts: row["attempts"])
    }
}
