import Foundation
import Hub
import struct MykilosKit.EmailDraft
import struct MykilosServices.MailMessageSummary

public struct MailDraftCard: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let inlet: Inlet.ID
    public var draft: EmailDraft
    public var state: MailDraftState
    public var outboxID: OutboxItem.ID?
}

extension MailModel {
    public func draft(_ id: UUID) -> MailDraftCard? { drafts.first { $0.id == id } }

    @discardableResult
    public func compose(to: String? = nil) -> UUID? {
        guard let inlet = selectedInlet else { return nil }
        return add(inlet: inlet, EmailDraft(to: to, subject: "", body: ""))
    }

    @discardableResult
    public func reply(to messageID: String, all: Bool = false) async -> UUID? {
        guard let inlet = cardInlet(messageID) ?? selectedInlet, let summary = summary(messageID) else { return nil }
        let own = engineAccount(inlet)
        let fromOwn = !own.isEmpty && MailAddresses.email(summary.fromRaw) == own
        let to = fromOwn ? summary.toRaw : summary.fromRaw
        var cc: String?
        if all {
            let taken = Set(MailAddresses.split(to).map(MailAddresses.email) + [own])
            let others = MailAddresses.split(summary.toRaw + "," + summary.ccRaw)
                .filter { !taken.contains(MailAddresses.email($0)) }
            cc = others.isEmpty ? nil : others.joined(separator: ", ")
        }
        let quote = await quoted(messageID, summary: summary)
        let draft = EmailDraft(to: to.isEmpty ? nil : to, cc: cc, subject: Self.prefixed("Re:", summary.subject),
                               body: quote, inReplyTo: summary.id,
                               threadID: summary.threadID.isEmpty ? nil : summary.threadID)
        return add(inlet: inlet, draft)
    }

    @discardableResult
    public func forward(_ messageID: String) async -> UUID? {
        guard let inlet = cardInlet(messageID) ?? selectedInlet, let summary = summary(messageID) else { return nil }
        let quote = await quoted(messageID, summary: summary)
        return add(inlet: inlet, EmailDraft(subject: Self.prefixed("Fwd:", summary.subject), body: quote))
    }

    public func edit(_ id: UUID, _ change: (inout EmailDraft) -> Void) {
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
        switch drafts[index].state {
        case .sending, .sent, .queuedInOutbox: return
        default: break
        }
        change(&drafts[index].draft)
        drafts[index].state = .edited
    }

    public func discard(_ id: UUID) {
        drafts.removeAll { $0.id == id }
    }

    public func send(_ id: UUID) async {
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
        let card = drafts[index]
        switch card.state {
        case .sending, .sent, .queuedInOutbox: return
        default: break
        }
        if card.draft.subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            drafts[index].state = .sendBlocked(.noSubject)
            return
        }
        let recipients = [card.draft.to, card.draft.cc, card.draft.bcc].compactMap { $0 }
        if recipients.allSatisfy({ MailAddresses.split($0).isEmpty }) {
            drafts[index].state = .sendBlocked(.noRecipient)
            return
        }
        drafts[index].state = .sending
        let outcome = await engine.send(card.inlet, card.draft)
        outbox = engine.outbox
        guard let now = drafts.firstIndex(where: { $0.id == id }) else { return }
        switch outcome {
        case .sent:
            drafts[now].state = .sent
        case .queued(let outboxID):
            drafts[now].outboxID = outboxID
            drafts[now].state = .queuedInOutbox
            reconcileDrafts()
        }
    }

    func reconcileDrafts() {
        for index in drafts.indices {
            guard let outboxID = drafts[index].outboxID else { continue }
            guard let item = outbox.first(where: { $0.id == outboxID }) else {
                if drafts[index].state == .queuedInOutbox { drafts[index].state = .sent }
                continue
            }
            switch item.state {
            case .failed(let hint): drafts[index].state = .sendFailed(hint)
            case .waiting, .sending: drafts[index].state = .queuedInOutbox
            }
        }
    }

    func add(inlet: Inlet.ID, _ draft: EmailDraft) -> UUID {
        let card = MailDraftCard(id: UUID(), inlet: inlet, draft: draft, state: .idle, outboxID: nil)
        drafts.append(card)
        return card.id
    }

    func engineAccount(_ inlet: Inlet.ID) -> String {
        accounts.first { $0.id == inlet }?.account.lowercased() ?? ""
    }

    func quoted(_ id: String, summary: MailMessageSummary) async -> String {
        let text = await messageText(id) ?? summary.snippet
        let date = summary.receivedAt.map { ISO8601DateFormatter().string(from: $0) } ?? ""
        let head = [summary.from, date].filter { !$0.isEmpty }.joined(separator: ", ")
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        return "\n\n" + head + "\n" + lines.map { "> " + $0 }.joined(separator: "\n")
    }

    static func prefixed(_ prefix: String, _ subject: String) -> String {
        let trimmed = subject.trimmingCharacters(in: .whitespaces)
        return trimmed.lowercased().hasPrefix(prefix.lowercased()) ? trimmed : prefix + " " + trimmed
    }
}
