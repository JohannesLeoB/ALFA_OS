import Core
import Foundation
import GRDB
import Hub
import Storage

@MainActor
public final class MailboxStore: MailboxPort {
    let access: any AccessPort
    let database: SQLiteStore
    let outboxStore: OutboxStore
    let eventBus: Broadcast<MailboxEvent>
    let now: @Sendable () -> Date
    let range: @MainActor (Inlet.ID) -> MailboxRange
    let names: @MainActor (Inlet.ID) -> SenderNames
    let serverCopy: @MainActor (Inlet.ID) -> ServerCopy
    var watcher: Task<Void, Never>?
    var expunging: [Inlet.ID: Bool] = [:]
    var passes: [String: Task<Result<Void, HubFailure>, Never>] = [:]
    var olderOffered: [String: Bool] = [:]
    var dirty: [Inlet.ID: Set<String>] = [:]
    var running: [Inlet.ID: Int] = [:]
    var syncing: Set<Inlet.ID> = []
    var resync: Set<Inlet.ID> = []
    var offerings: [Inlet.ID: MailOffering] = [:]
    var progresses: [String: SyncProgress] = [:]

    public init(access: any AccessPort, database: SQLiteStore, outbox: OutboxStore, events: Broadcast<MailboxEvent>,
                now: @escaping @Sendable () -> Date = { Date() },
                range: @escaping @MainActor (Inlet.ID) -> MailboxRange = { _ in .standard },
                names: @escaping @MainActor (Inlet.ID) -> SenderNames = { _ in SenderNames() },
                serverCopy: @escaping @MainActor (Inlet.ID) -> ServerCopy = { _ in .standard }) {
        self.access = access
        self.database = database
        self.outboxStore = outbox
        self.eventBus = events
        self.now = now
        self.range = range
        self.names = names
        self.serverCopy = serverCopy
        watcher = Task { [weak self] in
            guard let stream = self?.access.events else { return }
            for await event in stream {
                guard let self else { return }
                await self.handle(event)
            }
        }
    }

    deinit {
        watcher?.cancel()
    }

    public var accounts: [Inlet] {
        access.configured(for: .mail).map { inlet in
            let chosen = names(inlet.id).chosen.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !chosen.isEmpty else { return inlet }
            var shown = inlet
            shown.title = chosen
            return shown
        }
    }

    public var events: AsyncStream<MailboxEvent> { eventBus.stream }

    public var hasFiles: Bool { !access.inlets(for: .files).isEmpty }

    public func folders(_ inlet: Inlet.ID) -> [Folder] {
        Self.folders(database, inlet)
    }

    nonisolated static func folders(_ database: SQLiteStore, _ inlet: Inlet.ID) -> [Folder] {
        (try? database.read { db in
            try Row.fetchAll(db, sql: "SELECT id, name, role FROM mail_folder WHERE inlet = ? ORDER BY position", arguments: [inlet])
                .map { Folder(id: $0["id"], name: $0["name"], role: FolderRole(rawValue: $0["role"]) ?? .other) }
        }) ?? []
    }

    nonisolated static func folderID(_ database: SQLiteStore, _ inlet: Inlet.ID, role: FolderRole) -> String? {
        folders(database, inlet).first { $0.role == role }?.id
    }

    func messages(_ inlet: Inlet.ID, folder: String) -> [MessageSummary] {
        Self.queryMessages(database, inlet: inlet, folder: folder)
    }

    public func cached(_ inlet: Inlet.ID, folder: String) async -> [MessageSummary] {
        let database = database
        return await Task.detached { Self.queryMessages(database, inlet: inlet, folder: folder) }.value
    }

    nonisolated private static func queryMessages(_ database: SQLiteStore, inlet: Inlet.ID, folder: String) -> [MessageSummary] {
        if folder == Folder.starredID { return starredMessages(database, inlet: inlet) }
        return (try? database.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM mail_message WHERE inlet = ? AND folder = ? ORDER BY receivedAt DESC, id DESC",
                             arguments: [inlet, folder]).map(summary)
        }) ?? []
    }

    public func lastSync(_ inlet: Inlet.ID, folder: String) -> Date? {
        let value = try? database.read { db in
            try Double.fetchOne(db, sql: "SELECT at FROM mail_sync WHERE inlet = ? AND folder = ?", arguments: [inlet, folder])
        }
        return value.flatMap { $0 }.map { Date(timeIntervalSince1970: $0) }
    }

    public func searchLocal(_ inlet: Inlet.ID, query: String) -> [MessageSummary] {
        let pattern = "%" + query.replacingOccurrences(of: "%", with: "") + "%"
        return (try? database.read { db in
            try Row.fetchAll(db, sql: """
                SELECT * FROM mail_message WHERE inlet = ?1
                AND (subject LIKE ?2 OR sender LIKE ?2 OR fromRaw LIKE ?2 OR toRaw LIKE ?2 OR ccRaw LIKE ?2 OR snippet LIKE ?2)
                GROUP BY id ORDER BY receivedAt DESC
                """,
                arguments: [inlet, pattern]).map(Self.summary)
        }) ?? []
    }

    public func searchOpen(_ inlet: Inlet.ID, query: String, excluding folders: Set<String>) async -> [MessageSummary] {
        let database = database
        return await Task.detached { Self.queryOpen(database, inlet: inlet, query: query, excluding: folders) }.value
    }

    nonisolated private static func queryOpen(_ database: SQLiteStore, inlet: Inlet.ID, query: String,
                                              excluding folders: Set<String>) -> [MessageSummary] {
        let pattern = "%" + query.replacingOccurrences(of: "%", with: "") + "%"
        let marks = Array(repeating: "?", count: folders.count).joined(separator: ",")
        return (try? database.read { db in
            try Row.fetchAll(db, sql: """
                SELECT * FROM mail_message WHERE inlet = ?
                AND (subject LIKE ? OR sender LIKE ? OR fromRaw LIKE ? OR toRaw LIKE ? OR ccRaw LIKE ? OR snippet LIKE ?)
                AND folder NOT IN (\(marks))
                GROUP BY id ORDER BY receivedAt DESC
                """,
                arguments: StatementArguments([inlet, pattern, pattern, pattern, pattern, pattern, pattern] + folders.sorted()))
                .map(summary)
        }) ?? []
    }

    public func unreadCount(_ inlet: Inlet.ID) -> Int {
        guard let inbox = inboxID(inlet) else { return 0 }
        return unseenCount(inlet, folder: inbox) ?? localUnseen(inlet, inbox)
    }

    func localUnseen(_ inlet: Inlet.ID, _ folder: String) -> Int {
        let count = try? database.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM mail_message WHERE inlet = ? AND folder = ? AND seen = 0",
                             arguments: [inlet, folder])
        }
        return count.flatMap { $0 } ?? 0
    }

    public func draftIDs(_ inlet: Inlet.ID) -> Set<String> {
        guard let drafts = folderID(inlet, role: .drafts) else { return [] }
        let ids = try? database.read { db in
            try String.fetchAll(db, sql: "SELECT id FROM mail_message WHERE inlet = ? AND folder = ?", arguments: [inlet, drafts])
        }
        return Set(ids ?? [])
    }

    public func inboxOnly(_ inlet: Inlet.ID) -> Bool {
        if let port = (try? transport(inlet)) as? any InboxOnlyPort { return port.inboxOnly }
        return (try? database.read { db in
            try Bool.fetchOne(db, sql: "SELECT EXISTS(SELECT 1 FROM mail_pop WHERE inlet = ?)", arguments: [inlet])
        }) ?? false
    }

    public func usesLabels(_ inlet: Inlet.ID) -> Bool {
        ((try? transport(inlet)) as? any LabelPort)?.usesLabels ?? false
    }

    public func refreshFolders(_ inlet: Inlet.ID) async throws(HubFailure) {
        let transport = try transport(inlet)
        do {
            let folders = try await transport.listFolders()
            try replaceFolders(inlet, folders)
        } catch {
            throw DeliveryEngine.hubFailure(error, inlet: inlet, access: access)
        }
        eventBus.emit(.foldersChanged(inlet))
    }

    func list(_ transport: any MailTransportPort, inlet: Inlet.ID, folder: String, query: String?, pageToken: String?,
              size: Int) async throws(HubFailure) -> MessagePage {
        try await remote(inlet) {
            try await transport.listMessages(folderID: folder, query: query, pageToken: pageToken, maxResults: size)
        }
    }

    func remote<T>(_ inlet: Inlet.ID, _ work: () async throws -> T) async throws(HubFailure) -> T {
        do {
            return try await work()
        } catch {
            throw DeliveryEngine.hubFailure(error, inlet: inlet, access: access)
        }
    }

    func write(_ inlet: Inlet.ID, _ work: () throws -> Void) throws(HubFailure) {
        do {
            try work()
        } catch {
            throw DeliveryEngine.hubFailure(error, inlet: inlet, access: access)
        }
    }

    public func body(_ inlet: Inlet.ID, messageID: String) async throws(HubFailure) -> MessageBody {
        if let kept = keptBody(inlet, messageID: messageID) { return kept }
        let transport = try transport(inlet)
        do {
            let fetched = try await transport.fetchBody(messageID: messageID)
            keepBody(inlet, messageID: messageID, fetched)
            return fetched
        } catch {
            throw DeliveryEngine.hubFailure(error, inlet: inlet, access: access)
        }
    }

    public func setFlags(_ inlet: Inlet.ID, messageID: String, add: Set<Flag>, remove: Set<Flag>) async throws(HubFailure) {
        let transport = try transport(inlet)
        do {
            try await transport.setFlags(messageID: messageID, add: add, remove: remove)
            try apply(inlet, messageID: messageID, add: add, remove: remove)
        } catch {
            throw DeliveryEngine.hubFailure(error, inlet: inlet, access: access)
        }
        announceChange(inlet, inboxID(inlet) ?? "")
    }

    @discardableResult
    public func archive(_ inlet: Inlet.ID, messageID: String) async throws(HubFailure) -> String? {
        let inbox = inboxID(inlet)
        let header = header(inlet, messageID: messageID)
        let target = folderID(inlet, role: .archive)
        let (touched, landed) = try await perform(inlet) { transport in
            try await transport.archive(messageID: messageID, folderID: target)
            let touched = try self.remove(inlet, messageID: messageID, folder: inbox ?? "")
            return (touched, await Self.landed(transport, messageID, header: header, folder: target))
        }
        announce(inlet, touched)
        return landed
    }

    @discardableResult
    public func move(_ inlet: Inlet.ID, messageID: String, toFolder: String) async throws(HubFailure) -> String? {
        let header = header(inlet, messageID: messageID)
        let (touched, landed) = try await perform(inlet) { transport in
            try await transport.move(messageID: messageID, toFolderID: toFolder)
            let touched = try self.remove(inlet, messageID: messageID, folder: nil)
            return (touched, await Self.landed(transport, messageID, header: header, folder: toFolder))
        }
        announce(inlet, touched)
        return landed
    }

    @discardableResult
    public func trash(_ inlet: Inlet.ID, messageID: String) async throws(HubFailure) -> String? {
        let header = header(inlet, messageID: messageID)
        let target = folderID(inlet, role: .trash)
        let (touched, landed) = try await perform(inlet) { transport in
            try await transport.trash(messageID: messageID, folderID: target)
            let touched = try self.remove(inlet, messageID: messageID, folder: nil)
            return (touched, await Self.landed(transport, messageID, header: header, folder: target))
        }
        announce(inlet, touched)
        return landed
    }

    private static func landed(_ transport: any MailTransportPort, _ messageID: String, header: String, folder: String?) async
        -> String? {
        guard messageID.contains(":") else { return messageID }
        guard let folder, !header.isEmpty,
              let page = try? await transport.listMessages(folderID: folder, query: nil, pageToken: nil, maxResults: MirrorEngine.landedSize) else {
            return nil
        }
        return page.messages.first { $0.messageIDHeader == header }?.id
    }

    public func offersSource(_ inlet: Inlet.ID) -> Bool {
        ((try? transport(inlet)) as? any SourcePort)?.offersSource ?? false
    }

    public func source(_ inlet: Inlet.ID, messageID: String) async throws(HubFailure) -> Data {
        try await perform(inlet) { transport in
            guard let source = transport as? any SourcePort else { throw MailFailure.unsupportedCapability("source") }
            return try await source.fetchSource(messageID: messageID)
        }
    }

    public func canPurge(_ inlet: Inlet.ID) -> Bool {
        expunging[inlet] ?? false
    }

    public func checkPurge(_ inlet: Inlet.ID) async {
        guard expunging[inlet] == nil, isConnected(inlet), let purging = (try? transport(inlet)) as? any PurgePort,
              let found = try? await purging.supportsPurge() else { return }
        expunging[inlet] = found
    }

    private func isConnected(_ inlet: Inlet.ID) -> Bool {
        accounts.first { $0.id == inlet }?.state.isConnected ?? false
    }

    public func purge(_ inlet: Inlet.ID, messageID: String) async throws(HubFailure) {
        guard canPurge(inlet) else { throw HubFailure.capabilityMissing(inlet, .mail) }
        let touched = try await perform(inlet) { transport in
            guard let purging = transport as? any PurgePort else { throw MailFailure.unsupportedCapability("purge") }
            try await purging.purge(messageID: messageID)
            return try self.remove(inlet, messageID: messageID, folder: nil)
        }
        announce(inlet, touched)
    }

    public func markSpam(_ inlet: Inlet.ID, messageID: String) async throws(HubFailure) {
        let target = folderID(inlet, role: .spam)
        let touched = try await perform(inlet) { transport in
            try await transport.markSpam(messageID: messageID, folderID: target)
            return try self.remove(inlet, messageID: messageID, folder: nil)
        }
        announce(inlet, touched)
    }

    public func attachment(_ inlet: Inlet.ID, messageID: String, attachmentID: String) async throws(HubFailure) -> Data {
        try await perform(inlet) { try await $0.fetchAttachment(messageID: messageID, attachmentID: attachmentID) }
    }

    public func thread(_ inlet: Inlet.ID, messageID: String, threadID: String) async throws(HubFailure) -> [MessageSummary] {
        try await perform(inlet) { try await $0.fetchThread(messageID: messageID, threadID: threadID) }
    }

    public func projectFolders() async throws(HubFailure) -> [ProjectFolder] {
        guard hasFiles else { throw HubFailure.provider(Hint(text: MessageTextKey.noInlet.rawValue)) }
        let stock = access.stock(.files, as: ProjectFolder.self)
        if stock.items.isEmpty { await stock.refresh() }
        if stock.items.isEmpty, case .disturbed(let hint) = stock.phase { throw HubFailure.provider(hint) }
        return stock.items
    }

    public func listFiles(_ inlet: Inlet.ID, folder: String) async throws(HubFailure) -> [FileEntry] {
        try await storage(inlet) { try await $0.files(in: folder) }
    }

    public func readFile(_ inlet: Inlet.ID, fileID: String) async throws(HubFailure) -> Data {
        try await storage(inlet) { try await $0.read(fileID) }
    }

    public func putFile(_ inlet: Inlet.ID, folder: String, name: String, mimeType: String, data: Data) async throws(HubFailure)
        -> FileEntry {
        try await storage(inlet) { try await $0.put(name: name, mimeType: mimeType, data: data, into: folder) }
    }

    private func storage<T>(_ inlet: Inlet.ID, _ work: (any FilesPort) async throws -> T) async throws(HubFailure) -> T {
        let port = try access.port((any FilesPort).self, for: inlet)
        do {
            return try await work(port)
        } catch {
            throw DeliveryEngine.hubFailure(error, inlet: inlet, access: access)
        }
    }

    private func perform<T>(_ inlet: Inlet.ID, _ work: (any MailTransportPort) async throws -> T) async throws(HubFailure) -> T {
        let transport = try transport(inlet)
        do {
            return try await work(transport)
        } catch {
            throw DeliveryEngine.hubFailure(error, inlet: inlet, access: access)
        }
    }

    func transport(_ inlet: Inlet.ID) throws(HubFailure) -> any MailTransportPort {
        try access.port((any MailTransportPort).self, for: inlet)
    }

    private func announce(_ inlet: Inlet.ID, _ folders: [String]) {
        for folder in folders { announceChange(inlet, folder) }
    }

    private func handle(_ event: InletEvent) async {
        switch event {
        case .inletChanged(let inlet):
            expunging[inlet] = nil
            offerings[inlet] = nil
            eventBus.emit(.accountsChanged)
        case .inletRemoved(let inlet):
            expunging[inlet] = nil
            offerings[inlet] = nil
            await purgeInlet(inlet)
        case .syncFinished(.mail, let inlet):
            startSync(inlet)
        case .syncFailed(.mail, let inlet, let hint):
            eventBus.emit(.syncFailed(inlet, hint))
        default:
            break
        }
    }

    private func purgeInlet(_ inlet: Inlet.ID) async {
        let prefix = inlet + "\n"
        let running = passes.filter { $0.key.hasPrefix(prefix) }.map(\.value)
        running.forEach { $0.cancel() }
        for task in running { _ = await task.value }
        let deleted: Void? = try? database.write { db in
            for table in ["mail_message", "mail_folder", "mail_sync", "mail_cursor", "mail_outbox", "mail_draft", "mail_body", "mail_pop"] {
                try db.execute(sql: "DELETE FROM \(table) WHERE inlet = ?", arguments: [inlet])
            }
        }
        guard deleted != nil else { return }
        olderOffered = olderOffered.filter { !$0.key.hasPrefix(prefix) }
        let changed = outboxStore.forget(inlet)
        eventBus.emit(.foldersChanged(inlet))
        if changed { eventBus.emit(.outboxChanged) }
        eventBus.emit(.accountsChanged)
    }

    private func startSync(_ inlet: Inlet.ID) {
        guard !syncing.contains(inlet) else {
            resync.insert(inlet)
            return
        }
        syncing.insert(inlet)
        Task {
            repeat {
                resync.remove(inlet)
                await sync(inlet)
            } while resync.contains(inlet)
            syncing.remove(inlet)
        }
    }

    private func sync(_ inlet: Inlet.ID) async {
        await outboxStore.pass(inlet)
        await warmSenders(inlet)
        do {
            try mirrorDeliveredFolders(inlet)
            if let inbox = inboxID(inlet) {
                try await refresh(inlet, folder: inbox)
            }
            for role in [FolderRole.drafts, .sent] {
                if let folder = folderID(inlet, role: role) { try await refresh(inlet, folder: folder) }
            }
            await countUnmirrored(inlet)
        } catch {
            eventBus.emit(.syncFailed(inlet, Self.syncHint(error, inlet: inlet)))
            return
        }
        eventBus.emit(.syncFinished(inlet))
    }

    nonisolated static func syncHint(_ error: HubFailure, inlet: Inlet.ID) -> Hint {
        if case .provider(let value) = error { return value }
        return Hint(text: MessageTextKey.offline.rawValue, detail: String(describing: error), fixIn: .inlet(inlet))
    }

    private func mirrorDeliveredFolders(_ inlet: Inlet.ID) throws(HubFailure) {
        let prefix = inlet + "/"
        let folders = access.stock(.mailboxes, as: Mailbox.self).items.filter { $0.inlet == inlet }.map {
            Folder(id: $0.id.replacingOccurrences(of: prefix, with: "", options: .anchored), name: $0.name,
                   role: FolderRole(rawValue: $0.role) ?? .other)
        }
        do {
            try replaceFolders(inlet, folders)
        } catch {
            throw DeliveryEngine.hubFailure(error, inlet: inlet, access: access)
        }
        eventBus.emit(.foldersChanged(inlet))
    }

    func inboxID(_ inlet: Inlet.ID) -> String? {
        folderID(inlet, role: .inbox)
    }

    func folderID(_ inlet: Inlet.ID, role: FolderRole) -> String? {
        Self.folderID(database, inlet, role: role)
    }

    private func header(_ inlet: Inlet.ID, messageID: String) -> String {
        let value = try? database.read { db in
            try String.fetchOne(db, sql: "SELECT messageIDHeader FROM mail_message WHERE inlet = ? AND id = ? LIMIT 1",
                                arguments: [inlet, messageID])
        }
        return value.flatMap { $0 } ?? ""
    }

    private func replaceFolders(_ inlet: Inlet.ID, _ folders: [Folder]) throws {
        offerings[inlet] = nil
        try database.write { db in
            let before = try String.fetchAll(db, sql: "SELECT id FROM mail_folder WHERE inlet = ?", arguments: [inlet])
            let folders = MirrorEngine.withStarred(folders)
            let kept = Set(folders.map(\.id))
            if !kept.isEmpty {
                for gone in before where !kept.contains(gone) {
                    try db.execute(sql: "DELETE FROM mail_message WHERE inlet = ? AND folder = ?", arguments: [inlet, gone])
                    try db.execute(sql: "DELETE FROM mail_sync WHERE inlet = ? AND folder = ?", arguments: [inlet, gone])
                    for key in [Self.historyKey(gone), Self.validityKey(gone), Self.reachKey(gone), Self.olderKey(gone),
                                Self.refusedKey(gone), Self.countKey(gone)] {
                        try db.execute(sql: "DELETE FROM mail_cursor WHERE inlet = ? AND key = ?", arguments: [inlet, key])
                    }
                }
            }
            try db.execute(sql: "DELETE FROM mail_folder WHERE inlet = ?", arguments: [inlet])
            try Self.dropOrphanBodies(db, inlet: inlet)
            for (index, folder) in folders.enumerated() {
                try db.execute(sql: "INSERT OR REPLACE INTO mail_folder (inlet, id, name, role, position) VALUES (?, ?, ?, ?, ?)",
                               arguments: [inlet, folder.id, folder.name, folder.role.rawValue, index])
            }
        }
    }

    @discardableResult
    private func remove(_ inlet: Inlet.ID, messageID: String, folder: String?) throws -> [String] {
        markDirty(inlet, messageID)
        return try database.write { db in
            var sql = "SELECT folder FROM mail_message WHERE inlet = ? AND id = ?"
            var arguments: StatementArguments = [inlet, messageID]
            if let folder {
                sql += " AND folder = ?"
                arguments += [folder]
            }
            let folders = try String.fetchAll(db, sql: sql, arguments: arguments)
            try db.execute(sql: sql.replacingOccurrences(of: "SELECT folder", with: "DELETE"), arguments: arguments)
            try Self.dropOrphanBodies(db, inlet: inlet, ids: [messageID])
            return folders
        }
    }

    func markDirty(_ inlet: Inlet.ID, _ messageID: String) {
        guard running[inlet, default: 0] > 0 else { return }
        dirty[inlet, default: []].insert(messageID)
    }

    private func apply(_ inlet: Inlet.ID, messageID: String, add: Set<Flag>, remove: Set<Flag>) throws {
        markDirty(inlet, messageID)
        try database.write { db in
            let rows = try Row.fetchAll(db, sql: "SELECT folder, flags FROM mail_message WHERE inlet = ? AND id = ?",
                                        arguments: [inlet, messageID])
            for row in rows {
                var flags = Self.flags(row["flags"])
                flags.formUnion(add)
                flags.subtract(remove)
                try db.execute(sql: "UPDATE mail_message SET flags = ?, seen = ? WHERE inlet = ? AND folder = ? AND id = ?",
                               arguments: [Self.encode(flags), flags.contains(.seen) ? 1 : 0, inlet, row["folder"] as String, messageID])
            }
        }
    }

    nonisolated static func stamp(_ db: Database, inlet: Inlet.ID, folder: String, at date: Date) throws {
        try db.execute(sql: "INSERT OR REPLACE INTO mail_sync (inlet, folder, at) VALUES (?, ?, ?)",
                       arguments: [inlet, folder, date.timeIntervalSince1970])
    }

    nonisolated static func insert(_ db: Database, inlet: Inlet.ID, folder: String, _ m: MessageSummary) throws {
        try db.execute(sql: """
            INSERT OR REPLACE INTO mail_message
            (inlet, folder, id, position, thread, subject, sender, fromRaw, toRaw, ccRaw, replyToRaw, snippet, receivedAt, flags, seen, folderIDs, attachmentCount, messageIDHeader, attachments)
            VALUES (?, ?, ?, 0, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [inlet, folder, m.id, m.threadID, m.subject, m.from, m.fromRaw, m.toRaw, m.ccRaw, m.replyToRaw, m.snippet,
                        m.receivedAt?.timeIntervalSince1970, encode(m.flags), m.flags.contains(.seen) ? 1 : 0,
                        m.folderIDs.joined(separator: "\n"), m.attachmentCount, m.messageIDHeader,
                        try JSONEncoder().encode(m.attachments)])
    }

    nonisolated static func summary(_ row: Row) -> MessageSummary {
        let received: Double? = row["receivedAt"]
        let ids: String = row["folderIDs"]
        let stored: Data? = row["attachments"]
        let attachments = stored.flatMap { try? JSONDecoder().decode([AttachmentInfo].self, from: $0) } ?? []
        return MessageSummary(
            id: row["id"], threadID: row["thread"], subject: row["subject"], from: row["sender"], fromRaw: row["fromRaw"],
            toRaw: row["toRaw"], ccRaw: row["ccRaw"], replyToRaw: row["replyToRaw"], snippet: row["snippet"],
            receivedAt: received.map { Date(timeIntervalSince1970: $0) }, flags: flags(row["flags"]),
            folderIDs: ids.isEmpty ? [] : ids.components(separatedBy: "\n"), attachmentCount: row["attachmentCount"],
            attachments: attachments, messageIDHeader: row["messageIDHeader"])
    }

    nonisolated static func encode(_ flags: Set<Flag>) -> String {
        flags.map(\.rawValue).sorted().joined(separator: ",")
    }

    nonisolated static func flags(_ text: String) -> Set<Flag> {
        Set(text.split(separator: ",").compactMap { Flag(rawValue: String($0)) })
    }
}
