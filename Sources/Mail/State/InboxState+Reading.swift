import Foundation
import Hub

extension InboxState {
    func summary(_ id: String) -> MessageSummary? {
        summaries.first { $0.id == id } ?? cards.first { $0.id == id }?.summary
    }

    public func open(_ id: String, pin: Bool = false) async {
        guard let inlet = selectedInlet, let summary = summary(id) else { return }
        selectedMessage = id
        if let index = cards.firstIndex(where: { $0.id == id }) {
            if pin { cards[index].pinned = true }
            cards.append(cards.remove(at: index))
            attach(.message(id))
            return
        }
        dropPreviews()
        cards.append(OpenMessage(inlet: inlet, summary: summary, content: .bodyLoading, pinned: pin))
        attach(.message(id))
        trimCards()
        await loadBody(id)
        if !summary.flags.contains(.seen) { await setRead(id, true) }
    }

    public func close(_ id: String) {
        cards.removeAll { $0.id == id }
        detach(.message(id))
        if selectedMessage == id { selectedMessage = cards.last?.id }
    }

    func loadBody(_ id: String) async {
        guard let index = cards.firstIndex(where: { $0.id == id }) else { return }
        let inlet = cards[index].inlet
        do {
            let body = try await mailbox.body(inlet, messageID: id)
            guard let now = cards.firstIndex(where: { $0.id == id }) else { return }
            cards[now].content = content(for: body, fallback: cards[now].summary.snippet)
            cards[now].attachments = body.attachments
        } catch {
            guard let now = cards.firstIndex(where: { $0.id == id }) else { return }
            cards[now].content = .text(cards[now].summary.snippet)
        }
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

    func update(_ id: String, _ change: (inout OpenMessage) -> Void) {
        guard let index = cards.firstIndex(where: { $0.id == id }) else { return }
        change(&cards[index])
    }

    func setRead(_ id: String, _ read: Bool) async {
        await setFlag(id, .seen, on: read)
    }

    func setStarred(_ id: String, _ starred: Bool) async {
        await setFlag(id, .flagged, on: starred)
    }

    func setFlag(_ id: String, _ flag: Flag, on: Bool) async {
        guard let inlet = cardInlet(id) ?? selectedInlet else { return }
        do {
            try await mailbox.setFlags(inlet, messageID: id, add: on ? [flag] : [], remove: on ? [] : [flag])
        } catch {
            return
        }
        apply(id) { if on { $0.flags.insert(flag) } else { $0.flags.remove(flag) } }
        refreshCounts()
    }

    func cardInlet(_ id: String) -> Inlet.ID? { cards.first { $0.id == id }?.inlet }

    func apply(_ id: String, _ change: (inout MessageSummary) -> Void) {
        if let index = summaries.firstIndex(where: { $0.id == id }) { change(&summaries[index]) }
        update(id) { change(&$0.summary) }
    }

    func messageText(_ id: String) async -> String? {
        if let card = cards.first(where: { $0.id == id }) {
            switch card.content {
            case .text(let text): return text
            case .html(let html, _): return HTMLEngine.plain(html)
            case .bodyLoading: break
            }
        }
        guard let inlet = cardInlet(id) ?? selectedInlet else { return nil }
        guard let body = try? await mailbox.body(inlet, messageID: id) else { return nil }
        return body.text ?? body.html.map(HTMLEngine.plain)
    }
}
