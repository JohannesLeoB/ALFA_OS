import Foundation
import Hub

extension InboxState {
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
        return (goneDrafts[inlet] ?? []).union(plannedDrafts(inlet))
    }

    var localNeedle: String {
        typed == query ? "" : typed.lowercased()
    }

    var crossActive: Bool {
        let needle = localNeedle
        return scope == .all && !needle.isEmpty && crossInlet == selectedInlet && !crossQuery.isEmpty
            && needle.hasPrefix(crossQuery) && !Folder.queues(selectedFolder)
    }

    static func contains(_ summary: MessageSummary, _ needle: String) -> Bool {
        [summary.from, summary.fromRaw, summary.subject, summary.snippet]
            .joined(separator: " ").lowercased().contains(needle)
    }

    func search(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        query = trimmed
        typed = trimmed
        guard let inlet = selectedInlet, let folder = selectedFolder else { return }
        if Folder.queues(folder) {
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
}
