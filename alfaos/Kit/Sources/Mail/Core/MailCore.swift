import Foundation
import GRDB
import Hub
import enum AlfaServices.MailTransportError
import struct AlfaKit.EmailDraft
import protocol AlfaServices.MailTransport
import enum AlfaServices.MailFlag
import struct AlfaServices.MailFolder
import enum AlfaServices.MailFolderRole
import struct AlfaServices.MailStoredDraft
import struct AlfaServices.MailMessageBody
import struct AlfaServices.MailMessagePage
import struct AlfaServices.MailMessageSummary

@MainActor
public final class MailCore: MailEngine {
    public static let pageSize = 50

    private let hub: any HubAccess
    private let mirror: MailMirror
    private let now: @Sendable () -> Date
    private var items: [OutboxItem]
    private var unsaved: Set<OutboxItem.ID> = []
    private var unremoved: Set<OutboxItem.ID> = []
    private var listeners: [UUID: AsyncStream<MailEngineEvent>.Continuation] = [:]
    private var watcher: Task<Void, Never>?
    private var expunging: [Inlet.ID: Bool] = [:]

    public init(hub: any HubAccess, database: DatabaseQueue, now: @escaping @Sendable () -> Date = { Date() }) throws {
        self.hub = hub
        self.mirror = try MailMirror(database)
        self.now = now
        self.items = mirror.outbox()
        try? mirror.dropSent()
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

    public var accounts: [Inlet] { hub.configured(for: .mail) }

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

    public func searchOpen(_ inlet: Inlet.ID, query: String, excluding folders: Set<String>) async -> [MailMessageSummary] {
        let mirror = mirror
        return await Task.detached { mirror.searchOpen(inlet, query: query, excluding: folders) }.value
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

    private func mirrorDeliveredFolders(_ inlet: Inlet.ID) throws(HubError) {
        let prefix = inlet + "/"
        let folders = hub.stock(.mailboxes, as: MailboxRecord.self).items.filter { $0.inlet == inlet }.map {
            MailFolder(id: $0.id.replacingOccurrences(of: prefix, with: "", options: .anchored), name: $0.name,
                       role: MailFolderRole(rawValue: $0.role) ?? .other)
        }
        do {
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

    @discardableResult
    public func archive(_ inlet: Inlet.ID, messageID: String) async throws(HubError) -> String? {
        let inbox = mirror.inboxID(inlet)
        let header = mirror.header(inlet, messageID: messageID)
        let target = mirror.folderID(inlet, role: .archive)
        let (touched, landed) = try await perform(inlet) { transport in
            try await transport.archive(messageID: messageID)
            let touched = try self.mirror.remove(inlet, messageID: messageID, folder: inbox ?? "")
            return (touched, await Self.landed(transport, messageID, header: header, folder: target))
        }
        announce(inlet, touched)
        return landed
    }

    @discardableResult
    public func move(_ inlet: Inlet.ID, messageID: String, toFolder: String) async throws(HubError) -> String? {
        let header = mirror.header(inlet, messageID: messageID)
        let (touched, landed) = try await perform(inlet) { transport in
            try await transport.move(messageID: messageID, toFolderID: toFolder)
            let touched = try self.mirror.remove(inlet, messageID: messageID, folder: nil)
            return (touched, await Self.landed(transport, messageID, header: header, folder: toFolder))
        }
        announce(inlet, touched)
        return landed
    }

    @discardableResult
    public func trash(_ inlet: Inlet.ID, messageID: String) async throws(HubError) -> String? {
        let header = mirror.header(inlet, messageID: messageID)
        let target = mirror.folderID(inlet, role: .trash)
        let (touched, landed) = try await perform(inlet) { transport in
            try await transport.trash(messageID: messageID)
            let touched = try self.mirror.remove(inlet, messageID: messageID, folder: nil)
            return (touched, await Self.landed(transport, messageID, header: header, folder: target))
        }
        announce(inlet, touched)
        return landed
    }

    private static func landed(_ transport: any MailTransport, _ messageID: String, header: String, folder: String?) async -> String? {
        guard messageID.contains(":") else { return messageID }
        guard let folder, !header.isEmpty,
              let page = try? await transport.listMessages(folderID: folder, query: nil, pageToken: nil, maxResults: pageSize) else {
            return nil
        }
        return page.messages.first { $0.messageIDHeader == header }?.id
    }

    public func canPurge(_ inlet: Inlet.ID) -> Bool {
        expunging[inlet] ?? false
    }

    public func checkPurge(_ inlet: Inlet.ID) async {
        guard expunging[inlet] == nil, isConnected(inlet), let purging = (try? transport(inlet)) as? any MailPurging,
              let found = try? await purging.supportsPurge() else { return }
        expunging[inlet] = found
    }

    private func isConnected(_ inlet: Inlet.ID) -> Bool {
        accounts.first { $0.id == inlet }?.state.isConnected ?? false
    }

    public func purge(_ inlet: Inlet.ID, messageID: String) async throws(HubError) {
        guard canPurge(inlet) else { throw HubError.capabilityMissing(inlet, .mail) }
        let touched = try await perform(inlet) { transport in
            guard let purging = transport as? any MailPurging else { throw MailTransportError.unsupportedCapability("purge") }
            try await purging.purge(messageID: messageID)
            return try self.mirror.remove(inlet, messageID: messageID, folder: nil)
        }
        announce(inlet, touched)
    }

    public func markSpam(_ inlet: Inlet.ID, messageID: String) async throws(HubError) {
        let touched = try await perform(inlet) { transport in
            try await transport.markSpam(messageID: messageID)
            return try self.mirror.remove(inlet, messageID: messageID, folder: nil)
        }
        announce(inlet, touched)
    }

    public func attachment(_ inlet: Inlet.ID, messageID: String, attachmentID: String) async throws(HubError) -> Data {
        try await perform(inlet) { try await $0.fetchAttachment(messageID: messageID, attachmentID: attachmentID) }
    }

    public func thread(_ inlet: Inlet.ID, messageID: String, threadID: String) async throws(HubError) -> [MailMessageSummary] {
        try await perform(inlet) { try await $0.fetchThread(messageID: messageID, threadID: threadID) }
    }

    public func saveDraft(_ inlet: Inlet.ID, _ draft: EmailDraft, replacing draftID: String?) async throws(HubError) -> String {
        try await perform(inlet) { try await $0.saveDraft(draft, replacing: draftID) }
    }

    public func loadDraft(_ inlet: Inlet.ID, messageID: String) async throws(HubError) -> MailStoredDraft {
        try await perform(inlet) { try await $0.fetchDraft(messageID: messageID) }
    }

    public func deleteDraft(_ inlet: Inlet.ID, draftID: String) async throws(HubError) {
        try await perform(inlet) { try await $0.deleteDraft(id: draftID) }
    }

    public func send(_ inlet: Inlet.ID, _ draft: EmailDraft) async -> SendOutcome {
        await submit(OutboxItem(inlet: inlet, draft: draft))
    }

    public func sendDraft(_ inlet: Inlet.ID, draftID: String, _ draft: EmailDraft) async -> SendOutcome {
        await submit(OutboxItem(inlet: inlet, draft: draft, draftID: draftID))
    }

    public var hasFiles: Bool { !hub.inlets(for: .files).isEmpty }

    public func projectFolders() async throws(HubError) -> [ProjectFolderRecord] {
        guard hasFiles else { throw HubError.noInlet(.files) }
        let stock = hub.stock(.files, as: ProjectFolderRecord.self)
        if stock.items.isEmpty { await stock.refresh() }
        if stock.items.isEmpty, case .disturbed(let hint) = stock.state { throw HubError.provider(hint) }
        return stock.items
    }

    public func listFiles(_ inlet: Inlet.ID, folder: String) async throws(HubError) -> [FileEntry] {
        try await storage(inlet) { try await $0.files(in: folder) }
    }

    public func readFile(_ inlet: Inlet.ID, fileID: String) async throws(HubError) -> Data {
        try await storage(inlet) { try await $0.read(fileID) }
    }

    public func putFile(_ inlet: Inlet.ID, folder: String, name: String, mimeType: String, data: Data) async throws(HubError) -> FileEntry {
        try await storage(inlet) { try await $0.put(name: name, mimeType: mimeType, data: data, into: folder) }
    }

    private func storage<T>(_ inlet: Inlet.ID, _ work: (any FilesPort) async throws -> T) async throws(HubError) -> T {
        let port = try hub.port((any FilesPort).self, for: inlet)
        do {
            return try await work(port)
        } catch {
            throw MailFailure.hubError(error, inlet: inlet, hub: hub)
        }
    }

    private func perform<T>(_ inlet: Inlet.ID, _ work: (any MailTransport) async throws -> T) async throws(HubError) -> T {
        let transport = try transport(inlet)
        do {
            return try await work(transport)
        } catch {
            throw MailFailure.hubError(error, inlet: inlet, hub: hub)
        }
    }

    private func announce(_ inlet: Inlet.ID, _ folders: [String]) {
        for folder in folders { emit(.messagesChanged(inlet, folder: folder)) }
    }

    private func submit(_ queued: OutboxItem) async -> SendOutcome {
        var item = queued
        switch await deliver(&item) {
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
        await pass(nil)
    }

    public func resend(_ id: OutboxItem.ID, _ draft: EmailDraft, draftID: String?) async -> SendOutcome? {
        guard let index = items.firstIndex(where: { $0.id == id }), case .failed = items[index].state else { return nil }
        let old = items[index]
        items[index] = OutboxItem(id: id, inlet: old.inlet, draft: draft, messageID: old.messageID,
                                  draftID: draftID ?? old.draftID, state: .waiting, attempts: old.attempts)
        await retry(id, byUser: true)
        return items.contains { $0.id == id } ? .queued(id) : .sent
    }

    public func revise(_ id: OutboxItem.ID, _ draft: EmailDraft) {
        guard let index = items.firstIndex(where: { $0.id == id }), items[index].state == .waiting else { return }
        let old = items[index]
        items[index] = OutboxItem(id: id, inlet: old.inlet, draft: draft, messageID: old.messageID, draftID: old.draftID,
                                  state: .waiting, attempts: old.attempts)
        persist(id)
    }

    private func pass(_ inlet: Inlet.ID?) async {
        flush()
        for item in items where item.state == .waiting && (inlet == nil || item.inlet == inlet) {
            await retry(item.id)
        }
    }

    private func flush() {
        for id in unremoved where (try? mirror.remove(id)) != nil { unremoved.remove(id) }
        for id in unsaved { persist(id) }
    }

    private func persist(_ id: OutboxItem.ID) {
        guard let item = items.first(where: { $0.id == id }) else {
            unsaved.remove(id)
            return
        }
        do {
            try mirror.save(item)
            unsaved.remove(id)
        } catch {
            unsaved.insert(id)
        }
    }

    private func finish(_ id: OutboxItem.ID) {
        do {
            try mirror.remove(id)
            unremoved.remove(id)
        } catch {
            unremoved.insert(id)
            try? mirror.markSent(id)
        }
    }

    private enum Delivery {
        case sent
        case transient(Hint)
        case rejected(Hint)
    }

    private func deliver(_ item: inout OutboxItem, verify: Bool = false, byUser: Bool = false) async -> Delivery {
        let transport: any MailTransport
        do {
            transport = try self.transport(item.inlet)
        } catch {
            return .transient(Hint(text: MailTextKey.offline.rawValue, detail: String(describing: error)))
        }
        if verify {
            do {
                if try await transport.wasSent(messageID: item.messageID) { return .sent }
            } catch {
                let failure = MailFailure.classify(error, inlet: item.inlet, hub: hub)
                if failure.isTransient { return .transient(failure.hint) }
                if !byUser { return .rejected(failure.hint) }
            }
        }
        var outgoing = item.draft
        outgoing.messageID = item.messageID
        do {
            if let draftID = item.draftID {
                let current = try await transport.saveDraft(outgoing, replacing: draftID)
                item.draftID = current
                try await transport.sendDraft(id: current)
            } else {
                try await transport.send(outgoing)
            }
            return .sent
        } catch {
            switch MailFailure.classify(error, inlet: item.inlet, hub: hub) {
            case .transient(let hint): return .transient(hint)
            case .rejected(let hint): return .rejected(hint)
            }
        }
    }

    private func retry(_ id: OutboxItem.ID, byUser: Bool = false) async {
        guard let index = items.firstIndex(where: { $0.id == id }), items[index].state == .waiting else { return }
        items[index].startSending()
        var item = items[index]
        emit(.outboxChanged)
        let result = await deliver(&item, verify: true, byUser: byUser)
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
        emit(.outboxChanged)
    }

    private func store(_ item: OutboxItem) {
        items.append(item)
        persist(item.id)
        emit(.outboxChanged)
    }

    private func transport(_ inlet: Inlet.ID) throws(HubError) -> any MailTransport {
        try hub.port((any MailTransport).self, for: inlet)
    }

    private func handle(_ event: HubEvent) async {
        switch event {
        case .inletChanged(let inlet):
            expunging[inlet] = nil
            emit(.accountsChanged)
        case .inletRemoved(let inlet):
            expunging[inlet] = nil
            purge(inlet)
        case .syncFinished(.mail, let inlet):
            await sync(inlet)
        case .syncFailed(.mail, let inlet, let hint):
            emit(.syncFailed(inlet, hint))
        default:
            break
        }
    }

    private func purge(_ inlet: Inlet.ID) {
        guard (try? mirror.purge(inlet)) != nil else { return }
        let before = items.count
        items.removeAll { $0.inlet == inlet }
        emit(.foldersChanged(inlet))
        if items.count != before { emit(.outboxChanged) }
        emit(.accountsChanged)
    }

    private func sync(_ inlet: Inlet.ID) async {
        do {
            try mirrorDeliveredFolders(inlet)
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
        await pass(inlet)
        emit(.syncFinished(inlet))
    }

    private func emit(_ event: MailEngineEvent) {
        for continuation in listeners.values { continuation.yield(event) }
    }
}
