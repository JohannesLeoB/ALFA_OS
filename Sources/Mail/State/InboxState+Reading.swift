import Foundation
import Hub

extension InboxState {
    func summary(_ id: String) -> MessageSummary? {
        summaries.first { $0.id == id } ?? card(id)?.summary
    }

    public func open(_ id: String, pin: Bool = false) async {
        guard let inlet = selectedInlet, let summary = summary(id) else { return }
        selectedMessage = id
        if let index = cardIndex(id, in: inlet) {
            if pin { cards[index].pinned = true }
            cards.append(cards.remove(at: index))
            attach(.message(id))
            return
        }
        dropPreviews()
        cards.append(OpenMessage(inlet: inlet, summary: summary, content: .bodyLoading, pinned: pin))
        attach(.message(id))
        trimCards()
        await loadBody(id, in: inlet)
        if !summary.flags.contains(.seen) { await setFlag(id, .seen, on: true, in: inlet, quiet: true) }
    }

    public func close(_ id: String) {
        drop(id, in: selectedInlet)
    }

    func drop(_ id: String, in inlet: Inlet.ID?) {
        cards.removeAll { $0.id == id && $0.inlet == inlet }
        if inlet == selectedInlet {
            detach(.message(id))
            if selectedMessage == id { selectedMessage = cards.last { $0.inlet == selectedInlet }?.id }
        } else if let inlet {
            parked[inlet]?.stack.removeAll { $0 == .message(id) }
            if parked[inlet]?.front == .message(id) { parked[inlet]?.front = parked[inlet]?.stack.last }
        }
    }

    func loadBody(_ id: String, in owner: Inlet.ID? = nil) async {
        guard let inlet = owner ?? selectedInlet, cardIndex(id, in: inlet) != nil else { return }
        do {
            let body = try await mailbox.body(inlet, messageID: id)
            guard let now = cardIndex(id, in: inlet) else { return }
            cards[now].bodyFailed = false
            let loaded = content(for: body, fallback: cards[now].summary.snippet)
            cards[now].content = loaded
            if case .html(let html, _) = loaded { cards[now].htmlParts = HTMLEngine.parts(html) }
            cards[now].attachments = body.attachments
            cards[now].unsubscribe = body.unsubscribe
        } catch {
            guard let now = cardIndex(id, in: inlet) else { return }
            cards[now].content = .text(cards[now].summary.snippet)
            cards[now].bodyFailed = true
            post(.readFailed, undo: { [weak self] in await self?.loadBody(id, in: owner) })
        }
    }

    public func unsubscribe(_ id: String) async -> URL? {
        guard let inlet = selectedInlet, let index = cardIndex(id, in: inlet), let list = cards[index].unsubscribe else { return nil }
        let name = Self.sender(cards[index].summary)
        var done = false
        if list.oneClick, let web = list.web { done = await unsubscribePost(web) }
        if !done, let mail = list.mail, var draft = UnsubscribeEngine.draft(mail) {
            draft.from = mailbox.sender(inlet)
            _ = await outboxPort.send(inlet, draft)
            outbox = outboxPort.outbox
            done = true
        }
        guard done else { return list.web }
        if let now = cardIndex(id, in: inlet) { cards[now].unsubscribed = true }
        post(.unsubscribed(name.name.isEmpty ? name.address : name.name))
        return nil
    }

    public func retryBody(_ id: String) {
        Task { await loadBody(id) }
    }

    func content(for body: MessageBody, fallback: String) -> MessageContent {
        if let html = body.html { return .html(html, inlineImages: body.inlineImages) }
        if let text = body.text { return .text(text) }
        return .text(fallback)
    }

    public func allowRemoteImages(_ id: String) {
        update(id) { $0.remoteImagesAllowed = true }
    }

    public func toggleRecipients(_ id: String) {
        update(id) { $0.recipientsExpanded.toggle() }
    }

    func update(_ id: String, in owner: Inlet.ID? = nil, _ change: (inout OpenMessage) -> Void) {
        guard let index = cardIndex(id, in: owner ?? selectedInlet) else { return }
        change(&cards[index])
    }

    func setRead(_ id: String, _ read: Bool) async {
        await setFlag(id, .seen, on: read)
    }

    func setStarred(_ id: String, _ starred: Bool) async {
        await setFlag(id, .flagged, on: starred)
    }

    @discardableResult
    func setFlag(_ id: String, _ flag: Flag, on: Bool, in owner: Inlet.ID? = nil, quiet: Bool = false) async -> Bool {
        guard let inlet = owner ?? selectedInlet else { return false }
        do {
            try await mailbox.setFlags(inlet, messageID: id, add: on ? [flag] : [], remove: on ? [] : [flag])
        } catch {
            if !quiet {
                post(flag == .seen && on ? .readFailed : .flagFailed, undo: { [weak self] in await self?.setFlag(id, flag, on: on, in: owner) })
            }
            return false
        }
        apply(id, in: inlet) { if on { $0.flags.insert(flag) } else { $0.flags.remove(flag) } }
        refreshCounts()
        return true
    }

    func apply(_ id: String, in owner: Inlet.ID? = nil, _ change: (inout MessageSummary) -> Void) {
        let inlet = owner ?? selectedInlet
        if inlet == selectedInlet, let index = summaries.firstIndex(where: { $0.id == id }) { change(&summaries[index]) }
        update(id, in: inlet) { change(&$0.summary) }
    }

    func messageText(_ id: String) async -> String? {
        if let card = card(id) {
            switch card.content {
            case .text(let text): return text
            case .html(let html, _): return HTMLEngine.plain(html)
            case .bodyLoading: break
            }
        }
        guard let inlet = selectedInlet else { return nil }
        guard let body = try? await mailbox.body(inlet, messageID: id) else { return nil }
        return body.text ?? body.html.map(HTMLEngine.plain)
    }
}

extension InboxState {
    private static let signatureMarkers: Set<String> = ["-- ", "--"]
    private static let signatureMaxLines = 12
    private static let signatureKey = "signature:"

    public func thread(_ id: String) -> [ThreadItem] {
        guard let card = card(id) else { return [] }
        let source = card.conversation.isEmpty ? [card.summary] : card.conversation.sorted {
            ($0.receivedAt ?? .distantPast) < ($1.receivedAt ?? .distantPast)
        }
        let now = clock()
        return source.map { item in
            let current = item.id == id
            let party = Self.sender(item)
            let name = party.name.isEmpty ? party.address : party.name
            let date = ThreadDate.of(item.receivedAt, now: now)
            let open = card.quotesOpen.contains(item.id)
            let signatureOpen = card.quotesOpen.contains(Self.signatureKey + item.id)
            let recipients = Recipients(to: RecipientEngine.parse(item.toRaw), cc: RecipientEngine.parse(item.ccRaw))
            if current, let html = card.htmlParts {
                return ThreadItem(id: item.id, name: name, address: party.address, date: date, text: "", html: html.body,
                                  blockedHTML: html.blockedBody, quote: html.quote, quoteOpen: open, signature: nil,
                                  signatureOpen: false, recipients: recipients, current: true)
            }
            let raw = current ? (card.plainText ?? item.snippet) : (card.threadTexts[item.id] ?? item.snippet)
            let parts = Quoting.split(raw)
            let signed = Self.signatureSplit(parts.body)
            return ThreadItem(id: item.id, name: name, address: party.address, date: date, text: signed.body, html: nil,
                              blockedHTML: nil, quote: parts.quote, quoteOpen: open, signature: signed.signature,
                              signatureOpen: signatureOpen, recipients: recipients, current: current)
        }
    }

    static func signatureSplit(_ text: String) -> (body: String, signature: Quote?) {
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        guard let mark = lines.lastIndex(where: { signatureMarkers.contains($0) }), mark > 0,
              lines.count - mark - 1 <= signatureMaxLines else { return (text, nil) }
        let body = lines[..<mark].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        let tail = lines[(mark + 1)...].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, !tail.isEmpty else { return (text, nil) }
        let count = tail.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
        return (body, Quote(text: tail, lines: count))
    }

    public func toggleSignature(_ id: String, message: String) {
        toggleQuote(id, message: Self.signatureKey + message)
    }

    @discardableResult
    public func composeLink(_ reference: String) -> UUID? {
        guard let inlet = selectedInlet, let target = HTMLEngine.mailto(reference) else { return nil }
        let draft = Draft(to: target.to.isEmpty ? nil : target.to, cc: target.cc.isEmpty ? nil : target.cc,
                          subject: target.subject, body: target.body)
        return add(inlet: inlet, draft, signing: true)
    }

    public func toggleQuote(_ id: String, message: String) {
        update(id) { card in
            if card.quotesOpen.contains(message) { card.quotesOpen.remove(message) } else { card.quotesOpen.insert(message) }
        }
    }

    public func loadThreadTexts(_ id: String) async {
        guard let inlet = selectedInlet else { return }
        await loadThread(id)
        guard let index = cardIndex(id, in: inlet) else { return }
        for item in cards[index].conversation where item.id != id {
            guard let body = try? await mailbox.body(inlet, messageID: item.id) else { continue }
            let text = body.text ?? body.html.map(HTMLEngine.plain) ?? item.snippet
            update(id, in: inlet) { $0.threadTexts[item.id] = text }
        }
    }
}

extension InboxState {
    public var pickedInList: [String] {
        let listed = Set(rows.map(\.id))
        return picked.filter { listed.contains($0) }
    }

    public var picking: Bool { !pickedInList.isEmpty }

    public func pick(_ id: String) {
        if Folder.queues(selectedFolder) { return }
        if let index = picked.firstIndex(of: id) { picked.remove(at: index) } else { picked.append(id) }
    }

    public func pickAllToggle() {
        if Folder.queues(selectedFolder) { return }
        let all = rows.map(\.id)
        picked = pickedInList.count == all.count ? [] : all
    }

    public func clearPicked() {
        picked = []
    }

    public func pickRange(to id: String) {
        if Folder.queues(selectedFolder) { return }
        let order = rows.map(\.id)
        guard let end = order.firstIndex(of: id) else { return }
        guard let anchor = pickedInList.last.flatMap({ order.firstIndex(of: $0) }) else {
            pick(id)
            return
        }
        for item in order[min(anchor, end)...max(anchor, end)] where !picked.contains(item) { picked.append(item) }
    }

    public func bulk(_ kind: BulkAction) async {
        let list = pickedInList.compactMap { summary($0) }.filter { kind != .trash || !inTrash($0.id) }
        guard !list.isEmpty else { return }
        switch kind {
        case .read:
            let anyUnread = list.contains { !$0.flags.contains(.seen) }
            let inlet = selectedInlet
            var failed: [String] = []
            for item in list {
                if await !setFlag(item.id, .seen, on: anyUnread, in: inlet, quiet: true) { failed.append(item.id) }
            }
            picked = []
            if failed.isEmpty {
                post(.bulkRead(count: list.count, read: anyUnread))
            } else {
                post(.flagFailed, undo: { [weak self] in
                    self?.picked = failed
                    await self?.bulk(.read)
                })
            }
        case .archive, .trash:
            guard let inlet = selectedInlet else { return }
            let origin = selectedFolder
            let staysListed = kind == .archive && folders.first { $0.id == origin }?.role == .all
            let lifted = lift(list.map(\.id), in: inlet, keepListed: staysListed)
            let opening = reopen(lifted.next)
            picked = []
            var moved: [(id: String, landed: String?, inlet: Inlet.ID, origin: String?)] = []
            var failed: [(summary: MessageSummary, index: Int)] = []
            for entry in list {
                do {
                    let landed: String?
                    if kind == .archive {
                        landed = try await mailbox.archive(inlet, messageID: entry.id)
                    } else {
                        landed = try await mailbox.trash(inlet, messageID: entry.id)
                    }
                    moved.append((entry.id, landed, inlet, Self.serverFolder(origin, of: entry, in: folders, inboxFirst: kind == .archive)))
                } catch {
                    failed.append(lifted.entries.first { $0.summary.id == entry.id } ?? (entry, summaries.count))
                }
            }
            putBack(failed, in: inlet, folder: origin)
            refreshCounts()
            await opening?.value
            if !failed.isEmpty {
                let retry = failed.map(\.summary.id)
                post(kind == .archive ? .archiveFailed : .deleteFailed, undo: { [weak self] in
                    self?.picked = retry
                    await self?.bulk(kind)
                })
                return
            }
            let entries = moved
            let undo: @MainActor () async -> Void = { [weak self] in
                await self?.restore(entries, fromTrash: kind == .trash)
            }
            let undoable = moved.contains { $0.landed != nil }
            post(kind == .archive ? .bulkArchived(count: moved.count) : .bulkTrashed(count: moved.count), undo: undoable ? undo : nil)
        }
    }
}
