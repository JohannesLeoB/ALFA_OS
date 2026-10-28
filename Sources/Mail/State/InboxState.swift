import Foundation
import Hub
import Observation

@MainActor
@Observable
public final class InboxState {
    let mailbox: any MailboxPort
    let outboxPort: any OutboxPort
    public let contacts: ContactState

    public var accounts: [Inlet] = []
    var folders: [Folder] = []
    public var selectedInlet: Inlet.ID?
    public var selectedFolder: String?
    var summaries: [MessageSummary] = []
    var selectedMessage: String?
    public var filter: InboxFilter = .all
    var query = ""
    public var typed = ""
    var crossHits: [MessageSummary] = []
    var crossInlet: Inlet.ID?
    var crossQuery = ""
    var typeGeneration = 0
    public var unread: [Inlet.ID: Int] = [:]
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
    public var toast: Toast?
    var toastSerial = 0
    @ObservationIgnored var undoAction: (@MainActor () async -> Void)?
    @ObservationIgnored var sendAfterSave: Set<UUID> = []

    var phase: LoadPhase = .settled
    var generation = 0
    @ObservationIgnored var eventTask: Task<Void, Never>?
    @ObservationIgnored var searchTask: Task<Void, Never>?

    let clock: @Sendable () -> Date

    public init(mailbox: any MailboxPort, outbox: any OutboxPort, contacts: ContactState,
                clock: @escaping @Sendable () -> Date = { Date() }) {
        self.mailbox = mailbox
        self.outboxPort = outbox
        self.contacts = contacts
        self.clock = clock
    }

    public var now: Date { clock() }

    public var totalUnread: Int { unread.values.reduce(0, +) }

    public var selectedAccount: Inlet? { accounts.first { $0.id == selectedInlet } }

    public func hasUnread(_ id: Inlet.ID) -> Bool { (unread[id] ?? 0) > 0 }

    var sortedFolders: [Folder] {
        folders.enumerated().sorted { left, right in
            let l = Self.rank(left.element.role), r = Self.rank(right.element.role)
            return l == r ? left.offset < right.offset : l < r
        }.map(\.element)
    }

    public var rows: [ListEntry] {
        var counts: [String: Int] = [:]
        for summary in summaries where !summary.threadID.isEmpty { counts[summary.threadID, default: 0] += 1 }
        let needle = localNeedle
        return (crossActive ? crossHits : summaries).filter { filter.matches($0) && (needle.isEmpty || Self.contains($0, needle)) }.map {
            ListEntry(summary: $0, selected: $0.id == selectedMessage,
                      threadCount: $0.threadID.isEmpty ? 1 : counts[$0.threadID, default: 1])
        }
    }

    var localNeedle: String {
        typed == query ? "" : typed.lowercased()
    }

    var crossActive: Bool {
        let needle = localNeedle
        return searchScope == .all && !needle.isEmpty && crossInlet == selectedInlet && !crossQuery.isEmpty
            && needle.hasPrefix(crossQuery)
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
        case .connecting, .signedIn:
            if summaries.isEmpty { return .loading }
        case .created, .keychainUnreadable, .orphaned, .locked:
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
        if crossActive { return rows.isEmpty ? .emptySearch(query: typed, folder: folder) : .loaded }
        if summaries.isEmpty {
            return query.isEmpty ? .empty(folder: folder) : .emptySearch(query: query, folder: folder)
        }
        if rows.isEmpty { return localNeedle.isEmpty ? .noFilterMatch : .emptySearch(query: typed, folder: folder) }
        return .loaded
    }

    public func start() async {
        await refreshAccounts()
        if selectedInlet == nil { selectedInlet = accounts.first?.id }
        loadFoldersFromMailbox()
        refreshCounts()
        outbox = outboxPort.outbox
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
        phase = .settled
        loadFoldersFromMailbox()
        if let id, let folder = selectedFolder { summaries = mailbox.messages(id, folder: folder) }
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

    func search(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        query = trimmed
        typed = trimmed
        guard let inlet = selectedInlet, let folder = selectedFolder else { return }
        if trimmed.isEmpty {
            await loadSelection()
            return
        }
        generation += 1
        let mine = generation
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
        guard searchScope == .all, let inlet = selectedInlet else { return }
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
        generation += 1
        let mine = generation
        if query.isEmpty { summaries = mailbox.messages(inlet, folder: folder) }
        phase = .loading
        await checkPurge()
        guard mine == generation else { return }
        await fetch(inlet: inlet, folder: folder, query: query.isEmpty ? nil : query, generation: mine)
    }

    func fetch(inlet: Inlet.ID, folder: String, query: String?, generation mine: Int) async {
        do {
            let page = try await mailbox.loadPage(inlet, folder: folder, query: query, pageToken: nil)
            guard mine == generation else { return }
            if let query, searchScope == .all {
                let known = Set(page.messages.map(\.id))
                summaries = page.messages + scoped(mailbox.searchLocal(inlet, query: query), folder: folder)
                    .filter { !known.contains($0.id) }
            } else {
                summaries = page.messages
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
    }

    func refreshCounts() {
        var counts: [Inlet.ID: Int] = [:]
        for account in accounts { counts[account.id] = mailbox.unreadCount(account.id) }
        unread = counts
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
            mergeMirror(inlet: inlet, folder: folder)
            refreshCards(inlet: inlet, folder: folder)
            refreshCounts()
        case .newMail(let inlet, _):
            if let folder = selectedFolder, inlet == selectedInlet,
               folders.first(where: { $0.id == folder })?.role == .inbox {
                mergeMirror(inlet: inlet, folder: folder)
            }
            refreshCounts()
        case .outboxChanged:
            outbox = outboxPort.outbox
            reconcileDrafts()
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

    func mergeMirror(inlet: Inlet.ID, folder: String) {
        guard inlet == selectedInlet, folder == selectedFolder, query.isEmpty else { return }
        let mirror = mailbox.messages(inlet, folder: folder)
        var byID = Dictionary(mirror.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var merged = summaries.map { byID.removeValue(forKey: $0.id) ?? $0 }
        let fresh = mirror.filter { byID[$0.id] != nil }
        merged.insert(contentsOf: fresh, at: 0)
        summaries = merged
    }

    func refreshCards(inlet: Inlet.ID, folder: String) {
        guard cards.contains(where: { $0.inlet == inlet }) else { return }
        let mirror = Dictionary(mailbox.messages(inlet, folder: folder).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
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
        case .all: 4
        case .archive: 5
        case .spam: 6
        case .trash: 7
        case .other: 8
        }
    }

    func scoped(_ list: [MessageSummary], folder: String) -> [MessageSummary] {
        switch searchScope {
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
        folders.first { $0.id == selectedFolder }
    }
}
