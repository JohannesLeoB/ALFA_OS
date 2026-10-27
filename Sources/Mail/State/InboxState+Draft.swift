import Core
import Foundation
import Hub

extension InboxState {
    public func draft(_ id: UUID) -> OpenDraft? { drafts.first { $0.id == id } }

    @discardableResult
    public func compose(to: String? = nil) -> UUID? {
        guard let inlet = selectedInlet else { return nil }
        if to == nil, let open = stack.compactMap({ ref -> OpenDraft? in
            if case .draft(let id) = ref { return draft(id) }
            return nil
        }).first(where: { $0.state == .idle && $0.remoteID == nil && Self.blank($0.draft) }) {
            setFrom(open.id, inlet: inlet)
            bring(.draft(open.id))
            return open.id
        }
        return add(inlet: inlet, Draft(to: to, subject: "", body: ""))
    }

    static func blank(_ draft: Draft) -> Bool {
        (draft.to ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && draft.subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && draft.attachments.isEmpty
    }

    public func closeDraft(_ id: UUID) async {
        guard let card = draft(id) else { return }
        detach(.draft(id))
        if Self.blank(card.draft) {
            if card.remoteID == nil { drafts.removeAll { $0.id == id } }
            return
        }
        switch card.state {
        case .saved: break
        default: await save(id)
        }
        if case .saved = draft(id)?.state { post(.draftSaved) }
    }

    @discardableResult
    func reply(to messageID: String, all: Bool = false) async -> UUID? {
        guard let inlet = cardInlet(messageID) ?? selectedInlet, let summary = summary(messageID) else { return nil }
        let own = accountAddress(inlet)
        let fromOwn = !own.isEmpty && AddressEngine.email(summary.fromRaw) == own
        let to = fromOwn ? summary.toRaw : summary.fromRaw
        var cc: String?
        if all {
            let taken = Set(AddressListParser.split(to).map(AddressEngine.email) + [own])
            let others = AddressListParser.split(summary.toRaw + "," + summary.ccRaw)
                .filter { !taken.contains(AddressEngine.email($0)) }
            cc = others.isEmpty ? nil : others.joined(separator: ", ")
        }
        pin(messageID)
        let quote = await quoted(messageID, summary: summary)
        let draft = Draft(to: to.isEmpty ? nil : to, cc: cc, subject: Self.prefixed("Re:", summary.subject),
                          body: quote, inReplyTo: summary.messageIDHeader.isEmpty ? nil : summary.messageIDHeader,
                          threadID: summary.threadID.isEmpty ? nil : summary.threadID)
        return add(inlet: inlet, draft)
    }

    @discardableResult
    func forward(_ messageID: String) async -> UUID? {
        guard let inlet = cardInlet(messageID) ?? selectedInlet, let summary = summary(messageID) else { return nil }
        let wasPinned = card(messageID)?.pinned ?? false
        pin(messageID)
        guard let attachments = await originalAttachments(messageID, inlet: inlet) else {
            update(messageID) { $0.pinned = wasPinned }
            return nil
        }
        let quote = await quoted(messageID, summary: summary)
        return add(inlet: inlet, Draft(subject: Self.prefixed("Fwd:", summary.subject), body: quote, attachments: attachments))
    }

    private func originalAttachments(_ messageID: String, inlet: Inlet.ID) async -> [Attachment]? {
        let infos: [AttachmentInfo]
        if let card = card(messageID), card.content != .bodyLoading {
            infos = card.attachments
        } else {
            do {
                infos = try await mailbox.body(inlet, messageID: messageID).attachments
            } catch {
                return nil
            }
        }
        var loaded: [Attachment] = []
        for info in infos {
            guard let data = await attachmentData(messageID, attachmentID: info.id) else { return nil }
            loaded.append(Attachment(filename: info.filename, mimeType: info.mimeType, data: data))
        }
        return loaded
    }

    public func edit(_ id: UUID, _ change: (inout Draft) -> Void) {
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
        if drafts[index].state == .sent { return }
        change(&drafts[index].draft)
        switch drafts[index].state {
        case .sendFailed, .sending: return
        case .queuedInOutbox:
            if let outboxID = drafts[index].outboxID {
                outboxPort.revise(outboxID, drafts[index].draft)
                outbox = outboxPort.outbox
            }
        default: drafts[index].state = .edited
        }
    }

    public func save(_ id: UUID) async {
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
        switch drafts[index].state {
        case .saving, .sending, .sent, .queuedInOutbox: return
        default: break
        }
        drafts[index].state = .saving
        drafts[index].saveFailure = nil
        let card = drafts[index]
        do {
            let remoteID = try await outboxPort.saveDraft(card.inlet, card.draft, replacing: card.remoteID)
            if let now = drafts.firstIndex(where: { $0.id == id }) {
                drafts[now].remoteID = remoteID
                if drafts[now].state == .saving { drafts[now].state = .saved(clock()) }
            } else {
                try? await outboxPort.deleteDraft(card.inlet, draftID: remoteID)
            }
        } catch {
            if let now = drafts.firstIndex(where: { $0.id == id }) {
                drafts[now].saveFailure = Self.hint(error)
                drafts[now].state = .edited
            }
        }
        guard sendAfterSave.remove(id) != nil else { return }
        await send(id)
    }

    public func deleteDraft(_ id: UUID) async {
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
        if let remoteID = drafts[index].remoteID {
            do {
                try await outboxPort.deleteDraft(drafts[index].inlet, draftID: remoteID)
            } catch {
                guard let now = drafts.firstIndex(where: { $0.id == id }) else { return }
                drafts[now].saveFailure = Self.hint(error)
                return
            }
        }
        drafts.removeAll { $0.id == id }
        detach(.draft(id))
    }

    @discardableResult
    public func editDraft(_ messageID: String) async -> UUID? {
        guard let inlet = cardInlet(messageID) ?? selectedInlet else { return nil }
        let stored: StoredDraft
        do {
            stored = try await outboxPort.loadDraft(inlet, messageID: messageID)
        } catch {
            return nil
        }
        if let open = drafts.first(where: { $0.inlet == inlet && $0.remoteID == stored.id }) {
            attach(.draft(open.id))
            return open.id
        }
        let id = add(inlet: inlet, stored.draft)
        if let index = drafts.firstIndex(where: { $0.id == id }) { drafts[index].remoteID = stored.id }
        return id
    }

    public func send(_ id: UUID) async {
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
        let card = drafts[index]
        switch card.state {
        case .saving:
            sendAfterSave.insert(id)
            return
        case .sending, .sent, .queuedInOutbox: return
        default: break
        }
        let recipients = [card.draft.to, card.draft.cc, card.draft.bcc].compactMap { $0 }
        if card.draft.subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || recipients.allSatisfy({ AddressListParser.split($0).isEmpty }) {
            post(.recipientMissing)
            return
        }
        drafts[index].state = .sending
        let outcome: SendOutcome
        if let outboxID = card.outboxID, let again = await outboxPort.resend(outboxID, card.draft, draftID: card.remoteID) {
            outcome = again
        } else if let remoteID = card.remoteID {
            outcome = await outboxPort.sendDraft(card.inlet, draftID: remoteID, card.draft)
        } else {
            outcome = await outboxPort.send(card.inlet, card.draft)
        }
        outbox = outboxPort.outbox
        guard let now = drafts.firstIndex(where: { $0.id == id }) else { return }
        switch outcome {
        case .sent:
            drafts[now].state = .sent
        case .queued(let outboxID):
            drafts[now].outboxID = outboxID
            drafts[now].state = .queuedInOutbox
            if drafts[now].draft != card.draft { outboxPort.revise(outboxID, drafts[now].draft) }
            reconcileDrafts()
        }
    }

    func reconcileDrafts() {
        for index in drafts.indices {
            guard drafts[index].state == .queuedInOutbox, let outboxID = drafts[index].outboxID else { continue }
            guard let item = outbox.first(where: { $0.id == outboxID }) else {
                drafts[index].state = .sent
                continue
            }
            if let current = item.draftID { drafts[index].remoteID = current }
            switch item.state {
            case .failed(let hint): drafts[index].state = .sendFailed(hint)
            case .waiting, .sending: drafts[index].state = .queuedInOutbox
            }
        }
    }

    func add(inlet: Inlet.ID, _ draft: Draft) -> UUID {
        let card = OpenDraft(id: UUID(), inlet: inlet, draft: draft, state: .idle, outboxID: nil, remoteID: nil,
                             saveFailure: nil)
        drafts.append(card)
        attach(.draft(card.id))
        return card.id
    }

    func accountAddress(_ inlet: Inlet.ID) -> String {
        accounts.first { $0.id == inlet }?.account.lowercased() ?? ""
    }

    func quoted(_ id: String, summary: MessageSummary) async -> String {
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

    public func attach(_ id: UUID, filename: String, mimeType: String, data: Data) {
        edit(id) { $0.attachments.append(Attachment(filename: filename, mimeType: mimeType, data: data)) }
    }

    public func removeAttachment(_ id: UUID, at index: Int) {
        edit(id) { draft in
            guard draft.attachments.indices.contains(index) else { return }
            draft.attachments.remove(at: index)
        }
    }
}
