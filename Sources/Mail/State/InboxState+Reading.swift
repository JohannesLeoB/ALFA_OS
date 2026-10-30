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
        } catch {
            guard let now = cardIndex(id, in: inlet) else { return }
            cards[now].content = .text(cards[now].summary.snippet)
            cards[now].bodyFailed = true
            post(.readFailed, undo: { [weak self] in await self?.loadBody(id, in: owner) })
        }
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
