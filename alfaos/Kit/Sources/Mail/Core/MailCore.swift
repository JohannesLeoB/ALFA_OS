import Foundation
import GRDB
import Hub
import struct MykilosKit.EmailDraft
import protocol MykilosServices.MailTransport
import enum MykilosServices.MailFlag
import struct MykilosServices.MailFolder
import struct MykilosServices.MailMessageBody
import struct MykilosServices.MailMessagePage
import struct MykilosServices.MailMessageSummary

@MainActor
public final class MailCore: MailEngine {
    public static let pageSize = 50

    private let hub: any HubAccess
    private let mirror: MailMirror
    private let now: @Sendable () -> Date
    private var items: [OutboxItem]
    private var listeners: [UUID: AsyncStream<MailEngineEvent>.Continuation] = [:]
    private var watcher: Task<Void, Never>?

    public init(hub: any HubAccess, database: DatabaseQueue, now: @escaping @Sendable () -> Date = { Date() }) throws {
        self.hub = hub
        self.mirror = try MailMirror(database)
        self.now = now
        self.items = mirror.outbox()
        watcher = Task { [weak self] in
            guard let events = self?.hub.events else { return }
            for await event in events {
                guard let self else { return }
                await self.handle(event)
            }
        }
    }

    deinit {
        watcher?.cancel()
    }

    public var accounts: [Inlet] { hub.inlets(for: .mail) }

    public var outbox: [OutboxItem] { items }

    public var events: AsyncStream<MailEngineEvent> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<MailEngineEvent>.makeStream()
        listeners[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.listeners[id] = nil }
        }
        return stream
    }

    public func folders(_ inlet: Inlet.ID) -> [MailFolder] {
        mirror.folders(inlet)
    }

    public func messages(_ inlet: Inlet.ID, folder: String) -> [MailMessageSummary] {
        mirror.messages(inlet, folder: folder)
    }

    public func lastSync(_ inlet: Inlet.ID, folder: String) -> Date? {
        mirror.lastSync(inlet, folder: folder)
    }

    public func searchLocal(_ inlet: Inlet.ID, query: String) -> [MailMessageSummary] {
        mirror.search(inlet, query: query)
    }

    public func unreadCount(_ inlet: Inlet.ID) -> Int {
        mirror.unread(inlet)
    }

    public func refreshFolders(_ inlet: Inlet.ID) async throws(HubError) {
        let transport = try transport(inlet)
        do {
            let folders = try await transport.listFolders()
            try mirror.replaceFolders(inlet, folders)
        } catch {
            throw MailFailure.hubError(error, inlet: inlet, hub: hub)
        }
        emit(.foldersChanged(inlet))
    }

    public func loadPage(_ inlet: Inlet.ID, folder: String, query: String?, pageToken: String?) async throws(HubError) -> MailMessagePage {
        let transport = try transport(inlet)
        let page: MailMessagePage
        do {
            page = try await transport.listMessages(folderID: folder, query: query, pageToken: pageToken, maxResults: Self.pageSize)
        } catch {
            throw MailFailure.hubError(error, inlet: inlet, hub: hub)
        }
        guard query == nil else { return page }
        let known = mirror.messageIDs(inlet, folder: folder)
        let hadSync = mirror.lastSync(inlet, folder: folder) != nil
        do {
            if pageToken == nil {
                try mirror.replaceMessages(inlet, folder: folder, page.messages, at: now())
            } else {
                try mirror.appendMessages(inlet, folder: folder, page.messages, at: now())
            }
        } catch {
            throw MailFailure.hubError(error, inlet: inlet, hub: hub)
        }
        emit(.messagesChanged(inlet, folder: folder))
        if pageToken == nil, hadSync, folder == mirror.inboxID(inlet) {
            let fresh = page.messages.filter { !known.contains($0.id) && !$0.flags.contains(.seen) }.count
            if fresh > 0 { emit(.newMail(inlet, count: fresh)) }
        }
        return page
    }

    public func body(_ inlet: Inlet.ID, messageID: String) async throws(HubError) -> MailMessageBody {
        let transport = try transport(inlet)
        do {
            return try await transport.fetchBody(messageID: messageID)
        } catch {
            throw MailFailure.hubError(error, inlet: inlet, hub: hub)
        }
    }

    public func setFlags(_ inlet: Inlet.ID, messageID: String, add: Set<MailFlag>, remove: Set<MailFlag>) async throws(HubError) {
        let transport = try transport(inlet)
        do {
            try await transport.setFlags(messageID: messageID, add: add, remove: remove)
            try mirror.apply(inlet, messageID: messageID, add: add, remove: remove)
        } catch {
            throw MailFailure.hubError(error, inlet: inlet, hub: hub)
        }
        emit(.messagesChanged(inlet, folder: mirror.inboxID(inlet) ?? ""))
    }

    public func send(_ inlet: Inlet.ID, _ draft: EmailDraft) async -> SendOutcome {
        let item = OutboxItem(inlet: inlet, draft: draft)
        switch await deliver(item) {
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

    public func retryOutbox() async {
        for item in items where item.state == .waiting {
            await retry(item.id)
        }
    }

    private enum Delivery {
        case sent
        case transient(Hint)
        case rejected(Hint)
    }

    private func deliver(_ item: OutboxItem) async -> Delivery {
        let transport: any MailTransport
        do {
            transport = try self.transport(item.inlet)
        } catch {
            return .transient(Hint(text: MailTextKey.offline.rawValue, detail: String(describing: error)))
        }
        do {
            try await transport.send(item.draft)
            return .sent
        } catch {
            switch MailFailure.classify(error, inlet: item.inlet, hub: hub) {
            case .transient(let hint): return .transient(hint)
            case .rejected(let hint): return .rejected(hint)
            }
        }
    }

    private func retry(_ id: OutboxItem.ID) async {
        guard let index = items.firstIndex(where: { $0.id == id }), items[index].state == .waiting else { return }
        items[index].startSending()
        let item = items[index]
        emit(.outboxChanged)
        let result = await deliver(item)
        guard let current = items.firstIndex(where: { $0.id == id }) else { return }
        switch result {
        case .sent:
            items.remove(at: current)
            try? mirror.remove(id)
        case .transient:
            items[current].wait()
            try? mirror.save(items[current])
        case .rejected(let hint):
            items[current].fail(hint)
            try? mirror.save(items[current])
        }
        emit(.outboxChanged)
    }

    private func store(_ item: OutboxItem) {
        items.append(item)
        try? mirror.save(item)
        emit(.outboxChanged)
    }

    private func transport(_ inlet: Inlet.ID) throws(HubError) -> any MailTransport {
        try hub.port((any MailTransport).self, for: inlet)
    }

    private func handle(_ event: HubEvent) async {
        switch event {
        case .inletChanged:
            emit(.accountsChanged)
        case .syncFinished(.mail, let inlet):
            await sync(inlet)
        default:
            break
        }
    }

    private func sync(_ inlet: Inlet.ID) async {
        do {
            try await refreshFolders(inlet)
            if let inbox = mirror.inboxID(inlet) {
                _ = try await loadPage(inlet, folder: inbox, query: nil, pageToken: nil)
            }
        } catch {
            let hint: Hint
            if case .provider(let value) = error {
                hint = value
            } else {
                hint = Hint(text: MailTextKey.offline.rawValue, detail: String(describing: error), fixIn: .inlet(inlet))
            }
            emit(.syncFailed(inlet, hint))
            return
        }
        for item in items where item.inlet == inlet && item.state == .waiting {
            await retry(item.id)
        }
    }

    private func emit(_ event: MailEngineEvent) {
        for continuation in listeners.values { continuation.yield(event) }
    }
}
