import Core
import Foundation
import GRDB
import Hub
import Storage

extension MailboxStore {
    nonisolated static func key(_ inlet: Inlet.ID, _ folder: String) -> String {
        inlet + "\n" + folder
    }

    nonisolated static func historyKey(_ folder: String) -> String {
        "history\n" + folder
    }

    nonisolated static func validityKey(_ folder: String) -> String {
        "validity\n" + folder
    }

    nonisolated static func reachKey(_ folder: String) -> String {
        "reach\n" + folder
    }

    nonisolated static func olderKey(_ folder: String) -> String {
        "older\n" + folder
    }

    nonisolated static func refusedKey(_ folder: String) -> String {
        "refused\n" + folder
    }

    nonisolated static func countKey(_ folder: String) -> String {
        "unseen\n" + folder
    }

    func offering(_ inlet: Inlet.ID) -> MailOffering? {
        if let cached = offerings[inlet] { return cached }
        guard let transport = try? transport(inlet) else { return nil }
        let everywhere = (transport as? any EverywhereSearchPort)?.offersEverywhere(in: folders(inlet)) ?? false
        let made = MailOffering(ranges: MirrorEngine.ranges(transport), everywhere: everywhere)
        offerings[inlet] = made
        return made
    }

    public func ranges(_ inlet: Inlet.ID) -> [MailboxRange] {
        offering(inlet)?.ranges ?? []
    }

    public func canLoadOlder(_ inlet: Inlet.ID, folder: String) -> Bool {
        guard folder != Folder.starredID, !ranges(inlet).isEmpty else { return false }
        let key = Self.key(inlet, folder)
        if let known = olderOffered[key] { return known }
        let stored = cursor(inlet, Self.olderKey(folder)) == "1"
        olderOffered[key] = stored
        return stored
    }

    public func refresh(_ inlet: Inlet.ID, folder: String) async throws(HubFailure) {
        if folder == Folder.starredID { return }
        try await run(inlet, folder, older: false, own: false)
    }

    public func loadOlder(_ inlet: Inlet.ID, folder: String) async throws(HubFailure) {
        guard canLoadOlder(inlet, folder: folder) else { return }
        try await run(inlet, folder, older: true, own: true)
    }

    public func rangeChanged(_ inlet: Inlet.ID) async {
        clearRange(inlet)
        olderOffered = olderOffered.filter { !$0.key.hasPrefix(inlet + "\n") }
        var failure: HubFailure?
        for folder in syncedFolders(inlet) {
            do {
                try await run(inlet, folder, older: false, own: true, narrowed: true)
            } catch {
                failure = failure ?? error
            }
        }
        if let failure { eventBus.emit(.syncFailed(inlet, Self.syncHint(failure, inlet: inlet))) }
        startStoring(inlet)
    }

    func run(_ inlet: Inlet.ID, _ folder: String, older: Bool, own: Bool, narrowed: Bool = false) async throws(HubFailure) {
        let key = Self.key(inlet, folder)
        if !older, !own, let existing = passes[key] {
            let follow = followUps[key] ?? followUp(inlet, folder, after: existing)
            return try await follow.value.get()
        }
        while let existing = passes[key] { _ = await existing.value }
        try await start(inlet, folder, older: older, narrowed: narrowed).value.get()
    }

    private func start(_ inlet: Inlet.ID, _ folder: String, older: Bool, narrowed: Bool) -> Task<Result<Void, HubFailure>, Never> {
        let task = Task { await self.execute(inlet, folder, older: older, narrowed: narrowed) }
        passes[Self.key(inlet, folder)] = task
        return task
    }

    private func followUp(_ inlet: Inlet.ID, _ folder: String, after existing: Task<Result<Void, HubFailure>, Never>)
        -> Task<Result<Void, HubFailure>, Never> {
        let key = Self.key(inlet, folder)
        let task = Task { () -> Result<Void, HubFailure> in
            _ = await existing.value
            self.followUps[key] = nil
            guard !Task.isCancelled else { return .success(()) }
            if let running = self.passes[key] { return await running.value }
            return await self.start(inlet, folder, older: false, narrowed: false).value
        }
        followUps[key] = task
        return task
    }

    private func execute(_ inlet: Inlet.ID, _ folder: String, older: Bool, narrowed: Bool) async -> Result<Void, HubFailure> {
        running[inlet, default: 0] += 1
        let outcome = await access.track(inlet, .mail) { reporter -> Result<Void, HubFailure> in
            do throws(HubFailure) {
                try await self.pass(inlet, folder, older: older, narrowed: narrowed, reporter: reporter)
                await self.expire(inlet, folder)
                return .success(())
            } catch {
                return .failure(error)
            }
        }
        running[inlet, default: 1] -= 1
        if running[inlet] == 0 {
            running[inlet] = nil
            dirty[inlet] = nil
            fetched[inlet] = nil
        }
        passes[Self.key(inlet, folder)] = nil
        if Task.isCancelled, case .failure = outcome { return .success(()) }
        return outcome
    }

    private func expire(_ inlet: Inlet.ID, _ folder: String) async {
        guard folder == inboxID(inlet), let port = (try? transport(inlet)) as? any ServerCopyPort else { return }
        let policy = serverCopy(inlet)
        guard policy != .keep else { return }
        try? await port.expire(policy, now: now())
    }

    private func pass(_ inlet: Inlet.ID, _ folder: String, older: Bool, narrowed: Bool, reporter: SyncReporter) async throws(HubFailure) {
        let transport = try transport(inlet)
        guard let mirror = transport as? any MirrorPort, !mirror.ranges.isEmpty else {
            throw HubFailure.capabilityMissing(inlet, .mail)
        }
        defer { endProgress(inlet, folder) }
        let wanted = range(inlet).resolved(in: mirror.ranges)
        let hadSync = lastSync(inlet, folder: folder) != nil
        let since = older ? nil : MirrorEngine.cutoff(wanted, reach: reach(inlet, folder), now: now())
        let limit = older ? storedIDs(inlet, folder).count + MirrorEngine.olderStep : nil
        let storedHistory = cursor(inlet, Self.historyKey(folder))
        let revisit = storedHistory != nil && hadSync && !older && !narrowed && cursor(inlet, Self.refusedKey(folder)) == nil
        var history = storedHistory
        if storedHistory == nil || revisit {
            let current = try await remote(inlet) { try await mirror.startCursor() }
            if revisit, let current, current == storedHistory {
                try write(inlet) { try self.upsert(inlet, folder, []) }
                await storeCount(inlet, folder, transport)
                announceChange(inlet, folder)
                return
            }
            history = storedHistory ?? current
        }
        let listing = try await remote(inlet) { try await mirror.listIDs(folderID: folder, since: since, limit: limit) }
        guard !Task.isCancelled else { return }
        let stored = storedIDs(inlet, folder)
        let plan = MirrorEngine.plan(stored: stored, listed: listing.ids)
        let known = cursor(inlet, Self.validityKey(folder))
        let changed = known != nil && listing.validity != nil && listing.validity != known
        let newest = newestDate(inlet, folder)
        var fresh = 0
        var added = 0
        let missing = mirror.fillsPreviews ? unpreviewedIDs(inlet, folder) : []
        let fetching = plan.unknown + listing.ids.filter { missing.contains($0) }
        var done = 0
        if !fetching.isEmpty { setProgress(inlet, folder, SyncProgress(done: 0, total: fetching.count), reporter: reporter) }
        for chunk in MirrorEngine.chunks(fetching, size: MirrorEngine.chunkSize) {
            let found = try await remote(inlet) { try await mirror.fetchSummaries(folderID: folder, ids: chunk) }
            guard !Task.isCancelled else { return }
            let kept = found.filter { !isDirty(inlet, $0.id) }
            try write(inlet) { try self.upsert(inlet, folder, kept) }
            added += kept.count
            fresh += MirrorEngine.newerThan(kept, newest: newest)
            done += chunk.count
            announceChange(inlet, folder)
            setProgress(inlet, folder, SyncProgress(done: done, total: fetching.count), reporter: reporter)
        }
        let marked = cursor(inlet, Self.refusedKey(folder))
        if let reason = MirrorEngine.refusal(plan: plan, stored: stored.count, added: added, validityChanged: changed,
                                             narrowed: narrowed, confirmedEmpty: marked == MirrorEngine.Refusal.emptyListing.rawValue) {
            if marked != reason.rawValue {
                try write(inlet) { try self.setCursor(inlet, Self.refusedKey(folder), reason.rawValue) }
                eventBus.emit(.refused(inlet, folder: folder))
            }
            return
        }
        if marked != nil { try write(inlet) { try self.clearCursor(inlet, Self.refusedKey(folder)) } }
        guard !Task.isCancelled else { return }
        let removable = plan.gone.filter { !isDirty(inlet, $0) }
        if !removable.isEmpty {
            try write(inlet) { try self.drop(inlet, folder, ids: removable) }
            announceChange(inlet, folder)
        }
        if let validity = listing.validity, validity != known {
            try write(inlet) { try self.setCursor(inlet, Self.validityKey(folder), validity) }
        }
        let present = storedIDs(inlet, folder)
        let flagged = listing.ids.filter { present.contains($0) }
        let anchor = history
        let refreshed = try await remote(inlet) { try await mirror.refreshFlags(folderID: folder, known: flagged, cursor: anchor) }
        guard !Task.isCancelled else { return }
        try write(inlet) {
            try self.applyFlags(inlet, folder, refreshed.flags)
            if let next = refreshed.cursor { try self.setCursor(inlet, Self.historyKey(folder), next) }
            try self.upsert(inlet, folder, [])
            try self.setCursor(inlet, Self.olderKey(folder), listing.hasOlder ? "1" : "0")
        }
        olderOffered[Self.key(inlet, folder)] = listing.hasOlder
        if older, wanted != .all, let oldest = oldestDate(inlet, folder) {
            try write(inlet) { try self.setCursor(inlet, Self.reachKey(folder), String(oldest.timeIntervalSince1970)) }
        }
        await storeCount(inlet, folder, transport)
        announceChange(inlet, folder)
        if hadSync, fresh > 0, folder == inboxID(inlet) { eventBus.emit(.newMail(inlet, count: fresh)) }
    }

    func isDirty(_ inlet: Inlet.ID, _ messageID: String) -> Bool {
        dirty[inlet]?.contains(messageID) ?? false
    }

    func storedIDs(_ inlet: Inlet.ID, _ folder: String) -> Set<String> {
        let ids = (try? database.read { db in
            try String.fetchAll(db, sql: "SELECT id FROM mail_message WHERE inlet = ? AND folder = ?", arguments: [inlet, folder])
        }) ?? []
        return Set(ids)
    }

    func unpreviewedIDs(_ inlet: Inlet.ID, _ folder: String) -> Set<String> {
        let ids = (try? database.read { db in
            try String.fetchAll(db, sql: "SELECT id FROM mail_message WHERE inlet = ? AND folder = ? AND snippet = ''", arguments: [inlet, folder])
        }) ?? []
        return Set(ids)
    }

    func newestDate(_ inlet: Inlet.ID, _ folder: String) -> Date? {
        bound("MAX", inlet, folder)
    }

    func oldestDate(_ inlet: Inlet.ID, _ folder: String) -> Date? {
        bound("MIN", inlet, folder)
    }

    private func bound(_ function: String, _ inlet: Inlet.ID, _ folder: String) -> Date? {
        let value = try? database.read { db in
            try Double.fetchOne(db, sql: "SELECT \(function)(receivedAt) FROM mail_message WHERE inlet = ? AND folder = ? AND receivedAt >= ?",
                                arguments: [inlet, folder, MailboxRange.earliest.timeIntervalSince1970])
        }
        return value.flatMap { $0 }.map { Date(timeIntervalSince1970: $0) }
    }

    func syncedFolders(_ inlet: Inlet.ID) -> [String] {
        let all = (try? database.read { db in
            try String.fetchAll(db, sql: "SELECT folder FROM mail_sync WHERE inlet = ?", arguments: [inlet])
        }) ?? []
        let inbox = inboxID(inlet)
        return all.filter { $0 == inbox } + all.filter { $0 != inbox }.sorted()
    }

    func upsert(_ inlet: Inlet.ID, _ folder: String, _ messages: [MessageSummary]) throws {
        let date = now()
        try database.write { db in
            for message in messages { try Self.insert(db, inlet: inlet, folder: folder, message) }
            try Self.stamp(db, inlet: inlet, folder: folder, at: date)
        }
    }

    func drop(_ inlet: Inlet.ID, _ folder: String, ids: Set<String>) throws {
        try database.write { db in
            for chunk in MirrorEngine.chunks(ids.sorted(), size: MirrorEngine.dropSize) {
                let marks = Array(repeating: "?", count: chunk.count).joined(separator: ",")
                try db.execute(sql: "DELETE FROM mail_message WHERE inlet = ? AND folder = ? AND id IN (\(marks))",
                               arguments: StatementArguments([inlet, folder] + chunk))
            }
            try Self.dropOrphanBodies(db, inlet: inlet, ids: Array(ids))
        }
        attachments.sweep(inlet)
    }

    func record(_ saved: SavedDraft, of draft: Draft, replacing previous: String?, inlet: Inlet.ID, folder: String) throws {
        let replaced = previous.flatMap { $0 == saved.mirrorID ? nil : $0 }
        markDirty(inlet, saved.mirrorID)
        if let replaced { markDirty(inlet, replaced) }
        let account = access.configured(for: .mail).first { $0.id == inlet }?.account ?? ""
        let date = now()
        try database.write { db in
            let thread = try replaced.flatMap {
                try String.fetchOne(db, sql: "SELECT thread FROM mail_message WHERE inlet = ? AND folder = ? AND id = ?",
                                    arguments: [inlet, folder, $0])
            } ?? ""
            try Self.insert(db, inlet: inlet, folder: folder,
                            MirrorEngine.draftRow(saved.mirrorID, draft, folder: folder, account: account, thread: thread, at: date))
            guard let replaced else { return }
            try db.execute(sql: "DELETE FROM mail_message WHERE inlet = ? AND folder = ? AND id = ?", arguments: [inlet, folder, replaced])
            try Self.dropOrphanBodies(db, inlet: inlet, ids: [replaced])
        }
        if replaced != nil { attachments.sweep(inlet) }
        announceChange(inlet, folder)
    }

    func applyFlags(_ inlet: Inlet.ID, _ folder: String, _ flags: [String: Set<Flag>]) throws {
        let current = dirty[inlet] ?? []
        try database.write { db in
            for (id, set) in flags where !current.contains(id) {
                try db.execute(sql: "UPDATE mail_message SET flags = ?, seen = ? WHERE inlet = ? AND folder = ? AND id = ?",
                               arguments: [Self.encode(set), set.contains(.seen) ? 1 : 0, inlet, folder, id])
            }
        }
    }

    func cursor(_ inlet: Inlet.ID, _ key: String) -> String? {
        let value = try? database.read { db in
            try String.fetchOne(db, sql: "SELECT value FROM mail_cursor WHERE inlet = ? AND key = ?", arguments: [inlet, key])
        }
        return value.flatMap { $0 }
    }

    func setCursor(_ inlet: Inlet.ID, _ key: String, _ value: String) throws {
        try database.write { db in
            try db.execute(sql: "INSERT OR REPLACE INTO mail_cursor (inlet, key, value) VALUES (?, ?, ?)",
                           arguments: [inlet, key, value])
        }
    }

    func reach(_ inlet: Inlet.ID, _ folder: String) -> Date? {
        cursor(inlet, Self.reachKey(folder)).flatMap(Double.init).map { Date(timeIntervalSince1970: $0) }
    }

    func clearCursor(_ inlet: Inlet.ID, _ key: String) throws {
        try database.write { db in
            try db.execute(sql: "DELETE FROM mail_cursor WHERE inlet = ? AND key = ?", arguments: [inlet, key])
        }
    }

    func clearRange(_ inlet: Inlet.ID) {
        try? database.write { db in
            try db.execute(sql: "DELETE FROM mail_cursor WHERE inlet = ? AND (key LIKE ? OR key LIKE ?)",
                           arguments: [inlet, Self.reachKey("") + "%", Self.olderKey("") + "%"])
        }
    }
}

extension MailboxStore {
    private static let everywhereToken = "*"

    private static func searchable(_ folder: Folder) -> Bool {
        folder.role != .spam && folder.role != .trash && !folder.isLocal
    }

    public func canSearchEverywhere(_ inlet: Inlet.ID) -> Bool {
        guard let offering = offering(inlet) else { return false }
        return offering.everywhere || folders(inlet).filter(Self.searchable).count > 1
    }

    public func search(_ inlet: Inlet.ID, folder: String, query: String, scope: SearchScope,
                       continuation: SearchContinuation?) async throws(HubFailure) -> SearchPage {
        let transport = try transport(inlet)
        switch scope {
        case .here where folder == Folder.starredID:
            return SearchPage(messages: starredMatches(inlet, query: query))
        case .here:
            let page = try await list(transport, inlet: inlet, folder: folder, query: query,
                                      pageToken: continuation?.tokens[folder], size: MirrorEngine.pageSize)
            return SearchPage(messages: page.messages, continuation: page.nextPageToken.map { SearchContinuation(tokens: [folder: $0]) },
                              total: page.total)
        case .all:
            if offering(inlet)?.everywhere == true, let everywhere = transport as? any EverywhereSearchPort {
                let token = continuation?.tokens[Self.everywhereToken]
                let page = try await remote(inlet) {
                    try await everywhere.searchEverywhere(query: query, pageToken: token, maxResults: MirrorEngine.pageSize)
                }
                return SearchPage(messages: page.messages,
                                  continuation: page.nextPageToken.map { SearchContinuation(tokens: [Self.everywhereToken: $0]) },
                                  total: page.total)
            }
            return try await searchFolders(transport, inlet: inlet, query: query, continuation: continuation)
        }
    }

    private func searchFolders(_ transport: any MailTransportPort, inlet: Inlet.ID, query: String,
                               continuation: SearchContinuation?) async throws(HubFailure) -> SearchPage {
        let targets = folders(inlet).filter { Self.searchable($0) && (continuation?.tokens[$0.id] != nil || continuation == nil) }
        var found: [MessageSummary] = []
        var tokens: [String: String] = [:]
        var skipped: [String] = []
        var totals: [Int] = []
        var failure: HubFailure?
        for target in targets {
            let token = continuation?.tokens[target.id].flatMap { $0.isEmpty ? nil : $0 }
            do {
                let page = try await list(transport, inlet: inlet, folder: target.id, query: query, pageToken: token,
                                          size: MirrorEngine.pageSize)
                found += page.messages
                if let next = page.nextPageToken { tokens[target.id] = next }
                if let total = page.total { totals.append(total) }
            } catch {
                failure = error
                skipped.append(target.id)
                tokens[target.id] = token ?? ""
            }
        }
        if let failure, skipped.count == targets.count { throw failure }
        var seen = Set<String>()
        let unique = found.filter { seen.insert($0.id).inserted }
        let total = skipped.isEmpty && totals.count == targets.count ? totals.reduce(0, +) : nil
        return SearchPage(messages: MirrorEngine.sorted(unique), continuation: tokens.isEmpty ? nil : SearchContinuation(tokens: tokens),
                          skipped: skipped, total: continuation == nil ? total : nil)
    }
}

extension MailboxStore {
    public func unseenCount(_ inlet: Inlet.ID, folder: String) -> Int? {
        guard let text = cursor(inlet, Self.countKey(folder)), let cached = CountEngine.decode(text) else { return nil }
        return CountEngine.shown(cached, local: localUnseen(inlet, folder))
    }

    public func progress(_ inlet: Inlet.ID, folder: String) -> SyncProgress? {
        progresses[Self.key(inlet, folder)]
    }

    func setProgress(_ inlet: Inlet.ID, _ folder: String, _ value: SyncProgress, reporter: SyncReporter) {
        progresses[Self.key(inlet, folder)] = value
        let prefix = inlet + "\n"
        let current = progresses.filter { $0.key.hasPrefix(prefix) }.values
        let finished = fetched[inlet] ?? SyncProgress(done: 0, total: 0)
        reporter(done: finished.done + current.reduce(0) { $0 + $1.done }, total: finished.total + current.reduce(0) { $0 + $1.total })
        eventBus.emit(.progress(inlet, folder: folder))
    }

    func endProgress(_ inlet: Inlet.ID, _ folder: String) {
        guard let ended = progresses.removeValue(forKey: Self.key(inlet, folder)) else { return }
        let finished = fetched[inlet] ?? SyncProgress(done: 0, total: 0)
        fetched[inlet] = SyncProgress(done: finished.done + ended.done, total: finished.total + ended.total)
        eventBus.emit(.progress(inlet, folder: folder))
    }

    func countUnmirrored(_ inlet: Inlet.ID) async {
        guard let transport = try? transport(inlet) else { return }
        for folder in Self.folders(database, inlet) where FolderRole.countedRoles.contains(folder.role) {
            await storeCount(inlet, folder.id, transport)
            announceChange(inlet, folder.id)
        }
    }

    func storeCount(_ inlet: Inlet.ID, _ folder: String, _ transport: any MailTransportPort) async {
        guard let port = transport as? any UnseenCountPort, !Task.isCancelled,
              let count = try? await port.unseen(folderID: folder) else { return }
        let text = CountEngine.encode(count, local: localUnseen(inlet, folder))
        try? setCursor(inlet, Self.countKey(folder), text)
    }
}
