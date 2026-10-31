import Foundation
import Hub
import Observation

@MainActor
@Observable
public final class InboxState {
    let mailbox: any MailboxPort
    let outboxPort: any OutboxPort
    public let contacts: ContactState
    public let directory: ContactSourceState

    public var accounts: [Inlet] = []
    var folders: [Folder] = []
    public var selectedInlet: Inlet.ID?
    public var selectedFolder: String?
    var summaries: [MessageSummary] = []
    var selectedMessage: String?
    public var filter: InboxFilter = .all
    public var formatting = false
    var query = ""
    public var typed = ""
    var crossHits: [MessageSummary] = []
    var crossInlet: Inlet.ID?
    var crossQuery = ""
    var typeGeneration = 0
    public var unread: [Inlet.ID: Int] = [:]
    var folderUnseen: [String: Int] = [:]
    var progressSerial = 0
    var mirroredDrafts: [Inlet.ID: Set<String>] = [:]
    var goneDrafts: [Inlet.ID: Set<String>] = [:]
    var outbox: [OutboxItem] = []
    var cards: [OpenMessage] = []
    var drafts: [OpenDraft] = []
    var stack: [CardRef] = []
    var front: CardRef?
    public internal(set) var opened = 0
    var parked: [Inlet.ID: ParkedMailbox] = [:]
    var picked: [String] = []
    public var searchScope = SearchScope.all
    public var searching = false
    var purgeChecks = 0
    public var overview = Overview()
    public var tiles = false
    public var tileHot: String?
    public var toast: Toast?
    var toastSerial = 0
    @ObservationIgnored var undoAction: (@MainActor () async -> Void)?
    @ObservationIgnored var sendAfterSave: Set<UUID> = []
    @ObservationIgnored var draftWork: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored var editedWhileSaving: Set<UUID> = []
    @ObservationIgnored var heldSends: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored var autosaveSerials: [UUID: Int] = [:]
    @ObservationIgnored var autosaveTicking: Set<UUID> = []
    @ObservationIgnored var folderRefreshSerials: [String: Int] = [:]
    @ObservationIgnored var composing: Set<String> = []

    var phase: LoadPhase = .settled
    var searchContinuation: SearchContinuation?
    var searchTotal: Int?
    var mirrorSerial = 0
    var generation = 0
    @ObservationIgnored var eventTask: Task<Void, Never>?
    @ObservationIgnored var searchTask: Task<Void, Never>?
    @ObservationIgnored var reloadTask: Task<Void, Never>?
    @ObservationIgnored var pendingReloads: [(inlet: Inlet.ID, folder: String)] = []
    @ObservationIgnored var readSerials: [String: Int] = [:]

    let clock: @Sendable () -> Date
    let autosavePause: Duration
    let autosaveInterval: Duration
    let sendHold: Duration
    let signatures: @MainActor (Inlet.ID) -> MailboxSignature?
    let quoteTexts: @MainActor () -> QuoteTexts

    public init(mailbox: any MailboxPort, outbox: any OutboxPort, contacts: ContactState,
                directory: ContactSourceState = ContactSourceState(),
                clock: @escaping @Sendable () -> Date = { Date() },
                signatures: @escaping @MainActor (Inlet.ID) -> MailboxSignature? = { _ in nil },
                quoteTexts: @escaping @MainActor () -> QuoteTexts = { QuoteTexts() },
                autosavePause: Duration? = nil, autosaveInterval: Duration? = nil, sendHold: Duration = .zero) {
        self.mailbox = mailbox
        self.outboxPort = outbox
        self.contacts = contacts
        self.directory = directory
        self.clock = clock
        self.signatures = signatures
        self.quoteTexts = quoteTexts
        self.autosavePause = autosavePause ?? AutosaveEngine.pause
        self.autosaveInterval = autosaveInterval ?? AutosaveEngine.interval
        self.sendHold = sendHold
    }

    public var now: Date { clock() }

    public var totalUnread: Int { unread.values.reduce(0, +) }

    public var selectedAccount: Inlet? { accounts.first { $0.id == selectedInlet } }

    public func hasUnread(_ id: Inlet.ID) -> Bool { (unread[id] ?? 0) > 0 }

    var sortedFolders: [Folder] {
        listedFolders.enumerated().sorted { left, right in
            let l = Self.rank(left.element.role), r = Self.rank(right.element.role)
            return l == r ? left.offset < right.offset : l < r
        }.map(\.element)
    }

    public var rows: [ListEntry] {
        listed(limit: Int.max).entries
    }

    func listed(limit: Int) -> (entries: [ListEntry], total: Int) {
        var counts: [String: Int] = [:]
        if limit > 0 {
            for summary in summaries where !summary.threadID.isEmpty { counts[summary.threadID, default: 0] += 1 }
        }
        let needle = localNeedle
        var entries: [ListEntry] = []
        var total = 0
        let replaced = replacedDrafts
        for summary in crossActive ? crossHits : summaries where !replaced.contains(summary.id) && shown(summary, needle) {
            total += 1
            if entries.count < limit {
                entries.append(ListEntry(summary: summary, selected: summary.id == selectedMessage,
                                         threadCount: summary.threadID.isEmpty ? 1 : counts[summary.threadID, default: 1]))
            }
        }
        return (entries, total)
    }

    var hasRows: Bool {
        let needle = localNeedle
        let replaced = replacedDrafts
        return (crossActive ? crossHits : summaries).contains { !replaced.contains($0.id) && shown($0, needle) }
    }

    private func shown(_ summary: MessageSummary, _ needle: String) -> Bool {
        filter.matches(summary) && (needle.isEmpty || Self.contains(summary, needle))
    }

    private var replacedDrafts: Set<String> {
        guard let inlet = selectedInlet, currentFolder?.role == .drafts else { return [] }
        return goneDrafts[inlet] ?? []
    }

    var localNeedle: String {
        typed == query ? "" : typed.lowercased()
    }

    var crossActive: Bool {
        let needle = localNeedle
        return scope == .all && !needle.isEmpty && crossInlet == selectedInlet && !crossQuery.isEmpty
            && needle.hasPrefix(crossQuery) && selectedFolder != Folder.outboxID
    }

    static func contains(_ summary: MessageSummary, _ needle: String) -> Bool {
        [summary.from, summary.fromRaw, summary.subject, summary.snippet]
            .joined(separator: " ").lowercased().contains(needle)
    }

    public var listState: ListState {
        guard let account = selectedAccount else { return .notConnected(nil) }
        switch account.state {
        case .failed(let hint):
            return hint.text == Hint.signInExpiredText ? .signInExpired(account.id) : .failed(hint)
        case .connected, .working:
            break
        case .connecting:
            if summaries.isEmpty { return .loading }
        case .created, .keychainUnreadable:
            return .notConnected(account.id)
        }
        switch phase {
        case .loading: if summaries.isEmpty { return .loading }
        case .loadingMore: return .loadingMore
        case .failed(let hint):
            return hint.text == Hint.signInExpiredText ? .signInExpired(account.id) : .failed(hint)
        case .notConnected: return .notConnected(account.id)
        case .offline(let date): return .offline(lastSync: date)
        case .settled: break
        }
        let folder = selectedFolder ?? ""
        if crossActive { return hasRows ? .loaded : .emptySearch(query: typed, folder: folder) }
        if summaries.isEmpty {
            return query.isEmpty ? .empty(folder: folder) : .emptySearch(query: query, folder: folder)
        }
        if !hasRows { return localNeedle.isEmpty ? .noFilterMatch : .emptySearch(query: typed, folder: folder) }
        return .loaded
    }

    public func start() async {
        await refreshAccounts()
        if selectedInlet == nil { selectedInlet = accounts.first?.id }
        loadFoldersFromMailbox()
        refreshCounts()
        outbox = outboxPort.outbox
        restoreKeptDrafts()
        if eventTask == nil {
            eventTask = Task { [weak self] in
                guard let events = self?.mailbox.events else { return }
                for await event in events {
                    guard let self else { return }
                    await self.handle(event)
                }
            }
        }
        await loadSelection()
    }

    func refreshAccounts() async {
        accounts = mailbox.accounts
        let known = Set(accounts.map(\.id))
        var dropped = parked.filter { !known.contains($0.key) }.values.flatMap(\.stack)
        parked = parked.filter { known.contains($0.key) }
        if let current = selectedInlet, !known.contains(current) {
            dropped += stack
            enter(accounts.first?.id, parking: false)
        }
        await prune(dropped)
    }

    func prune(_ dropped: [CardRef]) async {
        let known = Set(accounts.map(\.id))
        let gone = Set(dropped.compactMap { ref -> UUID? in
            if case .draft(let id) = ref { return id }
            return nil
        })
        let doomed = drafts.filter { gone.contains($0.id) || !known.contains($0.inlet) }.map(\.id)
        for id in doomed {
            detach(.draft(id))
            for key in parked.keys {
                parked[key]?.stack.removeAll { $0 == .draft(id) }
                if parked[key]?.front == .draft(id) { parked[key]?.front = parked[key]?.stack.last }
            }
        }
        cards.removeAll { !known.contains($0.inlet) }
        for id in doomed where draft(id)?.state == .edited { await save(id) }
        drafts.removeAll { doomed.contains($0.id) }
    }

    func enter(_ id: Inlet.ID?, parking: Bool) {
        if parking, let current = selectedInlet {
            parked[current] = ParkedMailbox(stack: stack, front: front, message: selectedMessage)
        }
        let restored = id.flatMap { parked.removeValue(forKey: $0) } ?? ParkedMailbox()
        searchTask?.cancel()
        generation += 1
        typeGeneration += 1
        selectedInlet = id
        stack = restored.stack
        front = restored.front
        selectedMessage = restored.message
        picked = []
        selectedFolder = nil
        query = ""
        typed = ""
        searching = false
        crossHits = []
        crossInlet = nil
        crossQuery = ""
        overview.open = false
        overview.hot = nil
        summaries = []
        searchContinuation = nil
        searchTotal = nil
        phase = .settled
        loadFoldersFromMailbox()
        if let id, let folder = selectedFolder {
            phase = .loading
            showCached(inlet: id, folder: folder)
        }
    }

    private func showCached(inlet: Inlet.ID, folder: String) {
        let mine = generation
        Task { [weak self] in
            guard let self, let list = await self.read(inlet, folder), mine == self.generation else { return }
            self.summaries = list
            self.mirrorSerial += 1
            if self.phase == .loading { self.phase = .settled }
        }
    }

    @discardableResult
    public func swapAccount(_ id: Inlet.ID) -> Bool {
        guard id != selectedInlet, accounts.contains(where: { $0.id == id }) else { return false }
        enter(id, parking: true)
        return true
    }

    public func selectAccount(_ id: Inlet.ID) async {
        guard swapAccount(id) else { return }
        await loadSelection()
    }

    public func selectFolder(_ id: String) async {
        guard selectedInlet != nil else { return }
        if id != selectedFolder { summaries = [] }
        selectedFolder = id
        query = ""
        typed = ""
        filter = .all
        picked = []
        await loadSelection()
    }

    public func setFilter(_ value: InboxFilter) {
        filter = value
    }

    public func refreshFolders() async {
        guard let inlet = selectedInlet else { return }
        do {
            try await mailbox.refreshFolders(inlet)
        } catch {
            phase = .failed(Self.hint(error))
            return
        }
        loadFoldersFromMailbox()
    }

    public func refreshOthers() async {
        for inlet in accounts.map(\.id) where inlet != selectedInlet {
            try? await mailbox.refreshFolders(inlet)
            if let inbox = mailbox.folders(inlet).first(where: { $0.role == .inbox })?.id {
                try? await mailbox.refresh(inlet, folder: inbox)
            }
        }
        refreshCounts()
    }

    func search(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        query = trimmed
        typed = trimmed
        guard let inlet = selectedInlet, let folder = selectedFolder else { return }
        if folder == Folder.outboxID {
            query = ""
            return
        }
        if trimmed.isEmpty {
            await loadSelection()
            return
        }
        generation += 1
        let mine = generation
        searchContinuation = nil
        searchTotal = nil
        summaries = scoped(mailbox.searchLocal(inlet, query: trimmed), folder: folder)
        phase = .loading
        await fetch(inlet: inlet, folder: folder, query: trimmed, generation: mine)
    }

    public func type(_ text: String) async {
        typed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        typeGeneration += 1
        let mine = typeGeneration
        if typed.isEmpty {
            if !query.isEmpty { await submit("") }
            return
        }
        guard scope == .all, let inlet = selectedInlet else { return }
        let needle = typed
        let hidden = Set(folders.filter { $0.role == .spam || $0.role == .trash }.map(\.id))
        let hits = await mailbox.searchOpen(inlet, query: needle, excluding: hidden)
        guard mine == typeGeneration, inlet == selectedInlet else { return }
        crossHits = hits.filter { !$0.folderIDs.contains(where: hidden.contains) }
        crossInlet = inlet
        crossQuery = needle.lowercased()
    }

    public func submit(_ text: String) async {
        searchTask?.cancel()
        let task = Task {
            guard !Task.isCancelled else { return }
            await search(text)
        }
        searchTask = task
        await task.value
    }

    public var offersScope: Bool {
        selectedInlet.map(mailbox.canSearchEverywhere) ?? false
    }

    public var scope: SearchScope {
        searchScope == .all && offersScope ? .all : .here
    }

    public func ranges(_ inlet: Inlet.ID) -> [MailboxRange] {
        mailbox.ranges(inlet)
    }

    public func inboxOnly(_ inlet: Inlet.ID) -> Bool {
        mailbox.inboxOnly(inlet)
    }

    public var folderActions: Bool {
        !(selectedInlet.map(inboxOnly) ?? false)
    }

    public func rangeChanged(_ inlet: Inlet.ID) async {
        let watching = inlet == selectedInlet
        let mine = generation
        if watching { phase = .loading }
        await mailbox.rangeChanged(inlet)
        guard watching, mine == generation else { return }
        if phase == .loading { phase = .settled }
        if let folder = selectedFolder { await reloadNow(inlet: inlet, folder: folder) }
    }

    public func resultCount(loaded: Int) -> Int {
        guard let searchTotal, !query.isEmpty, localNeedle.isEmpty, filter == .all else { return loaded }
        return max(searchTotal, loaded)
    }

    public var listTail: ListTail? {
        _ = mirrorSerial
        guard phase == .settled || phase == .loadingMore, let inlet = selectedInlet, let folder = selectedFolder else { return nil }
        if !query.isEmpty { return searchContinuation == nil ? nil : .moreResults }
        return mailbox.canLoadOlder(inlet, folder: folder) ? .older : nil
    }

    public func loadTail() async {
        guard phase == .settled, let tail = listTail, let inlet = selectedInlet, let folder = selectedFolder else { return }
        let mine = generation
        phase = .loadingMore
        switch tail {
        case .older:
            do {
                try await mailbox.loadOlder(inlet, folder: folder)
            } catch {
                post(.olderFailed)
            }
            await reloadNow(inlet: inlet, folder: folder)
        case .moreResults:
            let text = query
            do {
                let page = try await mailbox.search(inlet, folder: folder, query: text, scope: scope, continuation: searchContinuation)
                if mine == generation, text == query {
                    let known = Set(summaries.map(\.id))
                    summaries = MirrorEngine.sorted(summaries + page.messages.filter { !known.contains($0.id) })
                    searchContinuation = page.continuation
                    if !page.skipped.isEmpty { post(.searchPartial) }
                }
            } catch {
                post(.moreFailed)
            }
        }
        if mine == generation, phase == .loadingMore { phase = .settled }
        mirrorSerial += 1
    }

    func fail(_ error: HubFailure, inlet: Inlet.ID, folder: String) {
        let hint = Self.hint(error)
        if case .notConnected = error {
            phase = .notConnected
        } else if hint.text == MessageTextKey.offline.rawValue {
            phase = .offline(mailbox.lastSync(inlet, folder: folder))
        } else {
            phase = .failed(hint)
        }
    }

    func fetchFolders(_ inlet: Inlet.ID) async {
        do {
            try await mailbox.refreshFolders(inlet)
            loadFoldersFromMailbox()
        } catch {
            fail(error, inlet: inlet, folder: selectedFolder ?? "")
        }
    }

    public func loadSelection() async {
        guard let inlet = selectedInlet else { return }
        if folders.isEmpty {
            await fetchFolders(inlet)
            if folders.isEmpty { return }
        }
        if selectedFolder == nil {
            selectedFolder = sortedFolders.first { $0.role == .inbox }?.id ?? sortedFolders.first?.id
        }
        guard let folder = selectedFolder else { return }
        if folder == Folder.outboxID {
            showOutbox()
            return
        }
        generation += 1
        let mine = generation
        phase = .loading
        if query.isEmpty, let list = await read(inlet, folder), mine == generation {
            summaries = list
            mirrorSerial += 1
        }
        await checkPurge()
        guard mine == generation else { return }
        await fetch(inlet: inlet, folder: folder, query: query.isEmpty ? nil : query, generation: mine)
    }

    func fetch(inlet: Inlet.ID, folder: String, query: String?, generation mine: Int) async {
        do {
            if let query {
                let page = try await mailbox.search(inlet, folder: folder, query: query, scope: scope, continuation: nil)
                guard mine == generation else { return }
                summaries = page.messages
                searchContinuation = page.continuation
                searchTotal = page.total
                if !page.skipped.isEmpty { post(.searchPartial) }
            } else {
                try await mailbox.refresh(inlet, folder: folder)
                guard mine == generation else { return }
                let list = await read(inlet, folder)
                guard mine == generation else { return }
                if let list { summaries = list }
                searchContinuation = nil
                searchTotal = nil
            }
            phase = .settled
        } catch {
            guard mine == generation else { return }
            fail(error, inlet: inlet, folder: folder)
        }
    }

    func loadFoldersFromMailbox() {
        guard let inlet = selectedInlet else {
            folders = []
            return
        }
        folders = mailbox.folders(inlet)
        if selectedFolder == nil {
            selectedFolder = sortedFolders.first { $0.role == .inbox }?.id ?? sortedFolders.first?.id
        }
        refreshCounts()
    }

    func refreshCounts() {
        var counts: [Inlet.ID: Int] = [:]
        for account in accounts { counts[account.id] = mailbox.unreadCount(account.id) }
        unread = counts
        var seen: [String: Int] = [:]
        if let inlet = selectedInlet {
            for folder in folders where FolderRole.countedRoles.contains(folder.role) {
                if let count = mailbox.unseenCount(inlet, folder: folder.id) { seen[folder.id] = count }
            }
        }
        folderUnseen = seen
        mirroredDrafts = Dictionary(accounts.map { ($0.id, mailbox.draftIDs($0.id)) }, uniquingKeysWith: { first, _ in first })
        goneDrafts = goneDrafts.reduce(into: [:]) { result, entry in
            let kept = entry.value.intersection(mirroredDrafts[entry.key] ?? [])
            if !kept.isEmpty { result[entry.key] = kept }
        }
    }

    func handle(_ event: MailboxEvent) async {
        switch event {
        case .accountsChanged:
            let before = selectedInlet
            let reachable = selectedAccount?.state.isConnected ?? true
            await refreshAccounts()
            refreshCounts()
            if selectedInlet != before, selectedInlet != nil {
                await loadSelection()
            } else if !reachable, selectedAccount?.state.isConnected == true {
                await loadSelection()
            }
            await checkPurge()
        case .foldersChanged(let inlet):
            if inlet == selectedInlet { loadFoldersFromMailbox() }
        case .messagesChanged(let inlet, let folder):
            scheduleReload(inlet: inlet, folder: folder)
            refreshCounts()
        case .newMail(let inlet, _):
            if let folder = selectedFolder, inlet == selectedInlet,
               folders.first(where: { $0.id == folder })?.role == .inbox {
                scheduleReload(inlet: inlet, folder: folder)
            }
            refreshCounts()
        case .progress(let inlet, let folder):
            if inlet == selectedInlet, folder == selectedFolder { progressSerial += 1 }
        case .outboxChanged:
            outbox = outboxPort.outbox
            reconcileDrafts()
            await refreshOutboxList()
        case .refused(let inlet, _):
            if inlet == selectedInlet { post(.mirrorRefused) }
        case .syncFailed(let inlet, let hint):
            guard inlet == selectedInlet, phase == .settled else { return }
            if hint.text == MessageTextKey.offline.rawValue, let folder = selectedFolder {
                phase = .offline(mailbox.lastSync(inlet, folder: folder))
            } else {
                phase = .failed(hint)
            }
        case .syncFinished(let inlet):
            guard inlet == selectedInlet else { return }
            switch phase {
            case .failed, .offline: await loadSelection()
            default: break
            }
        }
    }

    func scheduleReload(inlet: Inlet.ID, folder: String) {
        guard wantsReload(inlet: inlet, folder: folder) else { return }
        if !pendingReloads.contains(where: { $0.inlet == inlet && $0.folder == folder }) {
            pendingReloads.append((inlet, folder))
        }
        guard reloadTask == nil else { return }
        reloadTask = Task { [weak self] in await self?.drainReloads() }
    }

    private func drainReloads() async {
        while !pendingReloads.isEmpty {
            let batch = pendingReloads
            pendingReloads = []
            for item in batch { await reloadNow(inlet: item.inlet, folder: item.folder) }
            try? await Task.sleep(for: MirrorEngine.reloadInterval)
        }
        reloadTask = nil
    }

    private func wantsReload(inlet: Inlet.ID, folder: String) -> Bool {
        showsMirror(inlet: inlet, folder: folder) || cards.contains { $0.inlet == inlet }
    }

    private func showsMirror(inlet: Inlet.ID, folder: String) -> Bool {
        inlet == selectedInlet && folder == selectedFolder && query.isEmpty
    }

    func reloadNow(inlet: Inlet.ID, folder: String) async {
        guard wantsReload(inlet: inlet, folder: folder), let list = await read(inlet, folder) else { return }
        if showsMirror(inlet: inlet, folder: folder) {
            summaries = list
            mirrorSerial += 1
        }
        refreshCards(inlet: inlet, from: list)
    }

    func read(_ inlet: Inlet.ID, _ folder: String) async -> [MessageSummary]? {
        let key = inlet + "\n" + folder
        let mine = (readSerials[key] ?? 0) + 1
        readSerials[key] = mine
        let list = await mailbox.cached(inlet, folder: folder)
        return readSerials[key] == mine ? list : nil
    }

    func refreshCards(inlet: Inlet.ID, from list: [MessageSummary]) {
        guard cards.contains(where: { $0.inlet == inlet }) else { return }
        let mirror = Dictionary(list.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for index in cards.indices where cards[index].inlet == inlet {
            if let fresh = mirror[cards[index].id] { cards[index].summary = fresh }
        }
    }

    static func hint(_ error: HubFailure) -> Hint {
        switch error {
        case .provider(let hint): hint
        case .notConnected(let id): Hint(text: MessageTextKey.notConnected.rawValue, detail: id)
        case .capabilityMissing(let id, _): Hint(text: MessageTextKey.capabilityMissing.rawValue, detail: id)
        }
    }

    static func rank(_ role: FolderRole) -> Int {
        switch role {
        case .inbox: 0
        case .starred: 1
        case .sent: 2
        case .drafts: 3
        case .outbox: 4
        case .all: 5
        case .archive: 6
        case .spam: 7
        case .trash: 8
        case .other: 9
        }
    }

    func scoped(_ list: [MessageSummary], folder: String) -> [MessageSummary] {
        switch scope {
        case .here:
            return list.filter { $0.folderIDs.isEmpty || $0.folderIDs.contains(folder) }
        case .all:
            let hidden = Set(folders.filter { $0.role == .spam || $0.role == .trash }.map(\.id))
            return list.filter { !$0.folderIDs.contains(where: hidden.contains) }
        }
    }

    public func setSearching(_ on: Bool) async {
        searching = on
        if !on { typed = "" }
        if !on, !query.isEmpty { await search("") }
    }

    public func toggleScope() async {
        searchScope = searchScope == .here ? .all : .here
        if !query.isEmpty { await search(query) }
    }

    public var currentFolder: Folder? {
        listedFolders.first { $0.id == selectedFolder }
    }

    var listedFolders: [Folder] {
        folders + (hasUnsent ? [Folder(id: Folder.outboxID, name: "", role: .outbox)] : [])
    }
}
