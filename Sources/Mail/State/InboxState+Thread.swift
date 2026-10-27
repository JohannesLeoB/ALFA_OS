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
            let raw = current ? (card.plainText ?? item.snippet) : (card.threadTexts[item.id] ?? item.snippet)
            let parts = Quoting.split(raw)
            let party = Self.sender(item)
            return ThreadItem(id: item.id, name: party.name.isEmpty ? party.address : party.name, address: party.address,
                              date: ThreadDate.of(item.receivedAt, now: now), text: parts.body, quote: parts.quote,
                              quoteOpen: card.quotesOpen.contains(item.id), current: current)
        }
    }

    public func toggleQuote(_ id: String, message: String) {
        update(id) { card in
            if card.quotesOpen.contains(message) { card.quotesOpen.remove(message) } else { card.quotesOpen.insert(message) }
        }
    }

    public func loadThreadTexts(_ id: String) async {
        await loadThread(id)
        guard let card = card(id) else { return }
        for item in card.conversation where item.id != id {
            guard let inlet = cardInlet(id) ?? selectedInlet,
                  let body = try? await mailbox.body(inlet, messageID: item.id) else { continue }
            let text = body.text ?? body.html.map(HTMLEngine.plain) ?? item.snippet
            update(id) { $0.threadTexts[item.id] = text }
        }
    }
}
