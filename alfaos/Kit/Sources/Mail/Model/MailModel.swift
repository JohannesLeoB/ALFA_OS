import Foundation
import Hub
import Observation
import ShellCore
import enum AlfaServices.MailFlag
import struct AlfaServices.MailFolder
import enum AlfaServices.MailFolderRole
import struct AlfaServices.MailMessageSummary

enum MailLoadPhase: Equatable {
    case settled
    case loading
    case loadingMore
    case failed(Hint)
    case notConnected
    case offline(Date?)
}

@MainActor
@Observable
public final class MailModel {
    public let engine: any MailEngine

    public internal(set) var accounts: [Inlet] = []
    public internal(set) var folders: [MailFolder] = []
    public internal(set) var selectedInlet: Inlet.ID?
    public internal(set) var selectedFolder: String?
    public internal(set) var summaries: [MailMessageSummary] = []
    public internal(set) var selectedMessage: String?
    public internal(set) var filter: MailFilter = .all
    public internal(set) var query = ""
    public internal(set) var nextPageToken: String?
    public internal(set) var unread: [Inlet.ID: Int] = [:]
    public internal(set) var outbox: [OutboxItem] = []
    public internal(set) var cards: [ReadingCard] = []
    public internal(set) var cardLimit = Design.Count.stackMaxCards
    public internal(set) var drafts: [MailDraftCard] = []
    public internal(set) var actionFailures: [String: Hint] = [:]
    public var prefersHTML = true
    public internal(set) var stack: [CardRef] = []
    public internal(set) var front: CardRef?
    public internal(set) var picked: [String] = []
    public internal(set) var searchScope = MailSearchScope.all
    public internal(set) var searching = false
    public internal(set) var overview = MailOverview()
    public internal(set) var toast: MailToast?
    var toastSerial = 0
    @ObservationIgnored var undoAction: (@MainActor () async -> Void)?

    var phase: MailLoadPhase = .settled
    var generation = 0
    var eventTask: Task<Void, Never>?
    let commandContinuation: AsyncStream<MailCommand>.Continuation
    public let commands: AsyncStream<MailCommand>

    let clock: @Sendable () -> Date

    public init(engine: any MailEngine, clock: @escaping @Sendable () -> Date = { Date() }) {
        self.engine = engine
        self.clock = clock
        let (stream, continuation) = AsyncStream<MailCommand>.makeStream()
        commands = stream
        commandContinuation = continuation
    }

    public var now: Date { clock() }

    public var totalUnread: Int { unread.values.reduce(0, +) }

    public var selectedAccount: Inlet? { accounts.first { $0.id == selectedInlet } }

    public var sortedFolders: [MailFolder] {
        folders.enumerated().sorted { left, right in
            let l = Self.rank(left.element.role), r = Self.rank(right.element.role)
            return l == r ? left.offset < right.offset : l < r
        }.map(\.element)
    }

    public var rows: [MailRow] {
        var counts: [String: Int] = [:]
        for summary in summaries where !summary.threadID.isEmpty { counts[summary.threadID, default: 0] += 1 }
        return summaries.filter { filter.matches($0) }.map {
            MailRow(summary: $0, selected: $0.id == selectedMessage,
                    threadCount: $0.threadID.isEmpty ? 1 : counts[$0.threadID, default: 1])
        }
    }

    public var canLoadMore: Bool {
        guard nextPageToken != nil else { return false }
        switch phase {
        case .settled, .offline: return true
        default: return false
        }
    }

    public var listState: MailListState {
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
        if summaries.isEmpty {
            return query.isEmpty ? .empty(folder: folder) : .emptySearch(query: query, folder: folder)
        }
        if rows.isEmpty { return .noFilterMatch }
        return .loaded
    }

    public func start() async {
        refreshAccounts()
        if selectedInlet == nil { selectedInlet = accounts.first?.id }
        loadFoldersFromEngine()
        refreshCounts()
        outbox = engine.outbox
        if eventTask == nil {
            eventTask = Task { [weak self] in
                guard let events = self?.engine.events else { return }
                for await event in events {
                    guard let self else { return }
                    await self.handle(event)
                }
            }
        }
        await loadSelection()
    }

    public func stop() {
        eventTask?.cancel()
        eventTask = nil
    }

    public func refreshAccounts() {
        accounts = engine.accounts
        if let selectedInlet, !accounts.contains(where: { $0.id == selectedInlet }) {
            generation += 1
            self.selectedInlet = accounts.first?.id
            selectedFolder = nil
            selectedMessage = nil
            query = ""
            summaries = []
            nextPageToken = nil
            phase = .settled
            loadFoldersFromEngine()
        }
    }

    public func selectAccount(_ id: Inlet.ID) async {
        guard accounts.contains(where: { $0.id == id }) else { return }
        selectedInlet = id
        selectedFolder = nil
        query = ""
        summaries = []
        nextPageToken = nil
        selectedMessage = nil
        loadFoldersFromEngine()
        await loadSelection()
    }

    public func selectFolder(_ id: String) async {
        guard selectedInlet != nil else { return }
        selectedFolder = id
        query = ""
        filter = .all
        picked = []
        await loadSelection()
    }

    public func setFilter(_ value: MailFilter) {
        filter = value
    }

    public func setCardLimit(_ value: Int) {
        cardLimit = max(1, value)
        trimCards()
    }

    public func refreshFolders() async {
        guard let inlet = selectedInlet else { return }
        do {
            try await engine.refreshFolders(inlet)
        } catch {
            phase = .failed(Self.hint(error))
            return
        }
        loadFoldersFromEngine()
    }

    public func search(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        query = trimmed
        guard let inlet = selectedInlet, let folder = selectedFolder else { return }
        if trimmed.isEmpty {
            await loadSelection()
            return
        }
        generation += 1
        let mine = generation
        summaries = scoped(engine.searchLocal(inlet, query: trimmed), folder: folder)
        nextPageToken = nil
        phase = .loading
        await fetch(inlet: inlet, folder: folder, query: trimmed, token: nil, generation: mine, replace: true)
    }

    func fail(_ error: HubError, inlet: Inlet.ID, folder: String) {
        let hint = Self.hint(error)
        if case .notConnected = error {
            phase = .notConnected
        } else if hint.text == MailTextKey.offline.rawValue {
            phase = .offline(engine.lastSync(inlet, folder: folder))
        } else {
            phase = .failed(hint)
        }
    }

    func fetchFolders(_ inlet: Inlet.ID) async {
        do {
            try await engine.refreshFolders(inlet)
            loadFoldersFromEngine()
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
        nextPageToken = nil
        if query.isEmpty { summaries = engine.messages(inlet, folder: folder) }
        phase = .loading
        await fetch(inlet: inlet, folder: folder, query: query.isEmpty ? nil : query, token: nil,
                    generation: mine, replace: true)
    }

    public func loadMore() async {
        guard canLoadMore, let inlet = selectedInlet, let folder = selectedFolder, let token = nextPageToken else {
            return
        }
        generation += 1
        let mine = generation
        phase = .loadingMore
        await fetch(inlet: inlet, folder: folder, query: query.isEmpty ? nil : query, token: token,
                    generation: mine, replace: false)
    }

    func fetch(inlet: Inlet.ID, folder: String, query: String?, token: String?, generation mine: Int,
               replace: Bool) async {
        do {
            let page = try await engine.loadPage(inlet, folder: folder, query: query, pageToken: token)
            guard mine == generation else { return }
            if replace {
                if let query, searchScope == .all {
                    let known = Set(page.messages.map(\.id))
                    summaries = page.messages + scoped(engine.searchLocal(inlet, query: query), folder: folder)
                        .filter { !known.contains($0.id) }
                } else {
                    summaries = page.messages
                }
            } else {
                let known = Set(summaries.map(\.id))
                summaries += page.messages.filter { !known.contains($0.id) }
            }
            nextPageToken = page.nextPageToken
            phase = .settled
        } catch {
            guard mine == generation else { return }
            fail(error, inlet: inlet, folder: folder)
        }
    }

    func loadFoldersFromEngine() {
        guard let inlet = selectedInlet else {
            folders = []
            return
        }
        folders = engine.folders(inlet)
        if selectedFolder == nil {
            selectedFolder = sortedFolders.first { $0.role == .inbox }?.id ?? sortedFolders.first?.id
        }
    }

    public func refreshCounts() {
        var counts: [Inlet.ID: Int] = [:]
        for account in accounts { counts[account.id] = engine.unreadCount(account.id) }
        unread = counts
    }

    public func handle(_ event: MailEngineEvent) async {
        switch event {
        case .accountsChanged:
            let before = selectedInlet
            refreshAccounts()
            refreshCounts()
            if selectedInlet != before, selectedInlet != nil { await loadSelection() }
        case .foldersChanged(let inlet):
            if inlet == selectedInlet { loadFoldersFromEngine() }
        case .messagesChanged(let inlet, let folder):
            mergeMirror(inlet: inlet, folder: folder)
            refreshCounts()
        case .newMail(let inlet, _):
            if let folder = selectedFolder, inlet == selectedInlet,
               folders.first(where: { $0.id == folder })?.role == .inbox {
                mergeMirror(inlet: inlet, folder: folder)
            }
            refreshCounts()
        case .outboxChanged:
            outbox = engine.outbox
            reconcileDrafts()
        case .syncFailed(let inlet, let hint):
            guard inlet == selectedInlet, phase == .settled else { return }
            if hint.text == MailTextKey.offline.rawValue, let folder = selectedFolder {
                phase = .offline(engine.lastSync(inlet, folder: folder))
            } else {
                phase = .failed(hint)
            }
        }
    }

    func mergeMirror(inlet: Inlet.ID, folder: String) {
        guard inlet == selectedInlet, folder == selectedFolder, query.isEmpty else { return }
        let mirror = engine.messages(inlet, folder: folder)
        var byID = Dictionary(mirror.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var merged = summaries.map { byID.removeValue(forKey: $0.id) ?? $0 }
        let fresh = mirror.filter { byID[$0.id] != nil }
        merged.insert(contentsOf: fresh, at: 0)
        summaries = merged
    }

    static func hint(_ error: HubError) -> Hint {
        switch error {
        case .provider(let hint): hint
        case .notConnected(let id): Hint(text: MailTextKey.notConnected.rawValue, detail: id)
        case .noInlet: Hint(text: MailTextKey.noInlet.rawValue)
        case .capabilityMissing(let id, _): Hint(text: MailTextKey.capabilityMissing.rawValue, detail: id)
        }
    }

    static func rank(_ role: MailFolderRole) -> Int {
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
}

extension MailModel {
    func scoped(_ list: [MailMessageSummary], folder: String) -> [MailMessageSummary] {
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
        if !on, !query.isEmpty { await search("") }
    }

    public func toggleScope() async {
        searchScope = searchScope == .here ? .all : .here
        if !query.isEmpty { await search(query) }
    }

    public var currentFolder: MailFolder? {
        folders.first { $0.id == selectedFolder }
    }
}
