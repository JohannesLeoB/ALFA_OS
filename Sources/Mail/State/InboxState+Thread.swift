import Foundation

extension InboxState {
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
            if current, let html = card.htmlParts {
                return ThreadItem(id: item.id, name: name, address: party.address, date: date, text: "", html: html.body,
                                  blockedHTML: html.blockedBody, quote: html.quote, quoteOpen: open, current: true)
            }
            let raw = current ? (card.plainText ?? item.snippet) : (card.threadTexts[item.id] ?? item.snippet)
            let parts = Quoting.split(raw)
            return ThreadItem(id: item.id, name: name, address: party.address, date: date, text: parts.body, html: nil,
                              blockedHTML: nil, quote: parts.quote, quoteOpen: open, current: current)
        }
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
