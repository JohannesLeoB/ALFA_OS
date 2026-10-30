import Foundation

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
