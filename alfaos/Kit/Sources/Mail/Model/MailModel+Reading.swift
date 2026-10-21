import Foundation
import Hub
import enum AlfaServices.MailFlag
import struct AlfaServices.MailMessageBody
import struct AlfaServices.MailMessageSummary
import enum AlfaKit.MailLeadExtraktor

extension MailModel {
    public func summary(_ id: String) -> MailMessageSummary? {
        summaries.first { $0.id == id } ?? cards.first { $0.id == id }?.summary
    }

    public func actionFailure(for messageID: String) -> Hint? { actionFailures[messageID] }

    public func clearActionFailure(for messageID: String) {
        actionFailures[messageID] = nil
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
        cards.append(ReadingCard(inlet: inlet, summary: summary, content: .bodyLoading, pinned: pin))
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

    func trimCards() {
        while cards.count > cardLimit { detach(.message(cards.removeFirst().id)) }
    }

    func loadBody(_ id: String) async {
        guard let index = cards.firstIndex(where: { $0.id == id }) else { return }
        let inlet = cards[index].inlet
        do {
            let body = try await engine.body(inlet, messageID: id)
            guard let now = cards.firstIndex(where: { $0.id == id }) else { return }
            cards[now].content = content(for: body, fallback: cards[now].summary.snippet)
            cards[now].attachments = body.attachments
        } catch {
            actionFailures[id] = Self.hint(error)
            guard let now = cards.firstIndex(where: { $0.id == id }) else { return }
            cards[now].content = .text(cards[now].summary.snippet)
        }
    }

    func content(for body: MailMessageBody, fallback: String) -> MailCardContent {
        if prefersHTML, let html = body.html { return .html(html, inlineImages: body.inlineImages) }
        if let text = body.text { return .text(text) }
        if let html = body.html { return .html(html, inlineImages: body.inlineImages) }
        return .text(fallback)
    }

    public func allowRemoteImages(_ id: String) {
        update(id) { $0.remoteImagesAllowed = true }
    }

    public func toggleQuote(_ id: String) {
        update(id) { $0.quoteCollapsed.toggle() }
    }

    public func toggleSignature(_ id: String) {
        update(id) { $0.signatureCollapsed.toggle() }
    }

    public func toggleRecipients(_ id: String) {
        update(id) { $0.recipientsExpanded.toggle() }
    }

    func update(_ id: String, _ change: (inout ReadingCard) -> Void) {
        guard let index = cards.firstIndex(where: { $0.id == id }) else { return }
        change(&cards[index])
    }

    public func setRead(_ id: String, _ read: Bool) async {
        await setFlag(id, .seen, on: read)
    }

    public func setStarred(_ id: String, _ starred: Bool) async {
        await setFlag(id, .flagged, on: starred)
    }

    func setFlag(_ id: String, _ flag: MailFlag, on: Bool) async {
        guard let inlet = cardInlet(id) ?? selectedInlet else { return }
        do {
            try await engine.setFlags(inlet, messageID: id, add: on ? [flag] : [], remove: on ? [] : [flag])
        } catch {
            actionFailures[id] = Self.hint(error)
            return
        }
        actionFailures[id] = nil
        apply(id) { if on { $0.flags.insert(flag) } else { $0.flags.remove(flag) } }
        refreshCounts()
    }

    func cardInlet(_ id: String) -> Inlet.ID? { cards.first { $0.id == id }?.inlet }

    func apply(_ id: String, _ change: (inout MailMessageSummary) -> Void) {
        if let index = summaries.firstIndex(where: { $0.id == id }) { change(&summaries[index]) }
        update(id) { change(&$0.summary) }
    }

    func messageText(_ id: String) async -> String? {
        if let card = cards.first(where: { $0.id == id }) {
            switch card.content {
            case .text(let text): return text
            case .html(let html, _): return MailAddresses.plainText(html)
            default: break
            }
        }
        guard let inlet = cardInlet(id) ?? selectedInlet else { return nil }
        guard let body = try? await engine.body(inlet, messageID: id) else { return nil }
        return body.text ?? body.html.map(MailAddresses.plainText)
    }

    public func leadFromMail(_ id: String) async {
        guard let inlet = cardInlet(id) ?? selectedInlet, let summary = summary(id) else { return }
        let text = await messageText(id) ?? summary.snippet
        let lead = MailLeadExtraktor.extrahiere(fromRaw: summary.fromRaw, betreff: summary.subject, text: text,
                                                messageID: id)
        commandContinuation.yield(.leadFromMail(MailMessageRef(inlet: inlet, messageID: id), lead))
    }

    public func print(_ id: String) {
        guard let inlet = cardInlet(id) ?? selectedInlet, summary(id) != nil else { return }
        commandContinuation.yield(.print(MailMessageRef(inlet: inlet, messageID: id)))
    }

    public func exportPDF(_ id: String) {
        guard let inlet = cardInlet(id) ?? selectedInlet, summary(id) != nil else { return }
        commandContinuation.yield(.exportPDF(MailMessageRef(inlet: inlet, messageID: id)))
    }

    public func attachmentToProjectFolder(_ id: String, attachmentID: String, project: String? = nil) {
        guard let inlet = cardInlet(id) ?? selectedInlet, summary(id) != nil else { return }
        commandContinuation.yield(.attachmentToProjectFolder(
            MailMessageRef(inlet: inlet, messageID: id), attachmentID: attachmentID, project: project))
    }
}
