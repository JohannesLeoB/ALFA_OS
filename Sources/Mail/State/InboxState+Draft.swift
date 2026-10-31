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
        }).first(where: { $0.inlet == inlet && $0.state == .idle && $0.remoteID == nil && Self.blank($0.draft) }) {
            bring(.draft(open.id))
            return open.id
        }
        return add(inlet: inlet, Draft(to: to, subject: "", body: ""), signing: true)
    }

    static func blank(_ draft: Draft) -> Bool {
        (draft.to ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && draft.subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && draft.unsignedBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && draft.attachments.isEmpty
    }

    public func closeDraft(_ id: UUID) async {
        guard let card = draft(id) else { return }
        detach(.draft(id))
        if Self.blank(card.draft) {
            if card.remoteID == nil {
                drafts.removeAll { $0.id == id }
                dropLocal(id)
            }
            return
        }
        var failedToSend = false
        switch card.state {
        case .saved: break
        case .queuedInOutbox:
            post(.inOutbox)
            return
        case .sendFailed:
            failedToSend = true
            await save(id)
        default: await save(id)
        }
        if case .saved = draft(id)?.state {
            dropLocal(id)
            if failedToSend {
                post(.notSentInDrafts, undo: { [weak self] in
                    self?.attach(.draft(id))
                    await self?.send(id)
                })
            } else {
                post(.draftSaved)
            }
        }
    }

    @discardableResult
    func reply(to messageID: String, all: Bool = false) async -> UUID? {
        guard let inlet = selectedInlet, let summary = summary(messageID) else { return nil }
        let known = mailbox.knownSenders(inlet)
        let mine = Set(([accountAddress(inlet)] + known.map { $0.address.lowercased() }).filter { !$0.isEmpty })
        let fromOwn = mine.contains(AddressEngine.email(summary.fromRaw))
        let replyTo = summary.replyToRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let open = drafts.first(where: {
            $0.inlet == inlet && !summary.messageIDHeader.isEmpty && $0.draft.inReplyTo == summary.messageIDHeader
                && Self.stillWriting($0.state)
        }) {
            bring(.draft(open.id))
            return open.id
        }
        let key = inlet + "\n" + messageID + "\nreply"
        guard composing.insert(key).inserted else { return nil }
        defer { composing.remove(key) }
        let to = fromOwn ? summary.toRaw : (replyTo.isEmpty ? summary.fromRaw : replyTo)
        let chosen = SenderEngine.receiving(known, headers: fromOwn ? [summary.fromRaw] : [summary.toRaw, summary.ccRaw])
        var cc: String?
        if all {
            let taken = Set(AddressListParser.split(to).map(AddressEngine.email)).union(mine)
            let others = AddressListParser.split(summary.fromRaw + "," + summary.toRaw + "," + summary.ccRaw)
                .filter { !taken.contains(AddressEngine.email($0)) }
            cc = others.isEmpty ? nil : others.joined(separator: ", ")
        }
        pin(messageID)
        let quote = await quoted(messageID, summary: summary)
        let draft = Draft(to: to.isEmpty ? nil : to, cc: cc, subject: Self.prefixed("Re:", summary.subject),
                          body: quote, inReplyTo: summary.messageIDHeader.isEmpty ? nil : summary.messageIDHeader,
                          threadID: summary.threadID.isEmpty ? nil : summary.threadID, from: chosen)
        return add(inlet: inlet, draft, signing: true)
    }

    @discardableResult
    func forward(_ messageID: String) async -> UUID? {
        guard let inlet = selectedInlet, let summary = summary(messageID) else { return nil }
        let key = inlet + "\n" + messageID + "\nforward"
        guard composing.insert(key).inserted else { return nil }
        defer { composing.remove(key) }
        let wasPinned = card(messageID)?.pinned ?? false
        pin(messageID)
        guard let attachments = await originalAttachments(messageID, inlet: inlet) else {
            update(messageID) { $0.pinned = wasPinned }
            return nil
        }
        let quote = await quoted(messageID, summary: summary)
        let chosen = SenderEngine.receiving(mailbox.knownSenders(inlet), headers: [summary.toRaw, summary.ccRaw])
        return add(inlet: inlet, Draft(subject: Self.prefixed("Fwd:", summary.subject), body: quote, attachments: attachments,
                                       from: chosen), signing: true)
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

    public func setBody(_ id: UUID, text: String, html: String?) {
        edit(id) {
            $0.body = text
            $0.bodyHTML = html
        }
    }

    public func asksReceipt(_ id: UUID) -> Bool {
        drafts.first { $0.id == id }?.draft.receiptTo != nil
    }

    public func toggleReceipt(_ id: UUID) {
        guard let card = drafts.first(where: { $0.id == id }) else { return }
        let sender = card.draft.from?.address ?? accounts.first { $0.id == card.inlet }?.account
        edit(id) { $0.receiptTo = $0.receiptTo == nil ? sender : nil }
    }

    public func edit(_ id: UUID, _ change: (inout Draft) -> Void) {
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
        if drafts[index].state == .sent { return }
        change(&drafts[index].draft)
        drafts[index].tooLarge = false
        switch drafts[index].state {
        case .sendFailed, .sending: return
        case .queuedInOutbox:
            if let outboxID = drafts[index].outboxID {
                outboxPort.revise(outboxID, drafts[index].draft)
                outbox = outboxPort.outbox
            }
        case .saving:
            editedWhileSaving.insert(id)
            keepLocal(id)
            scheduleAutosave(id)
        default:
            drafts[index].state = .edited
            keepLocal(id)
            scheduleAutosave(id)
        }
    }

    public func save(_ id: UUID) async {
        let waited = draftWork[id] != nil
        await settle(id)
        guard let card = draft(id) else { return }
        if waited, card.state != .edited { return }
        switch card.state {
        case .sending, .sent, .queuedInOutbox: return
        default: break
        }
        await exclusive(id) { await self.storeRemotely(id) }
    }

    func settle(_ id: UUID) async {
        while let running = draftWork[id] { await running.value }
    }

    func exclusive(_ id: UUID, _ work: @escaping @MainActor @Sendable () async -> Void) async {
        let task = Task { @MainActor in
            await work()
            self.draftWork[id] = nil
        }
        draftWork[id] = task
        await task.value
        guard sendAfterSave.remove(id) != nil else { return }
        await send(id)
    }

    private func storeRemotely(_ id: UUID) async {
        var again = true
        while again {
            again = await storeOnce(id) && editedWhileSaving.contains(id)
            editedWhileSaving.remove(id)
        }
    }

    private func storeOnce(_ id: UUID) async -> Bool {
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return false }
        switch drafts[index].state {
        case .sending, .sent, .queuedInOutbox: return false
        default: break
        }
        if let queued = drafts[index].outboxID, outboxPort.outbox.first(where: { $0.id == queued })?.state.inFlight == true {
            holdForOutbox(index)
            return false
        }
        drafts[index].state = .saving
        drafts[index].saveFailure = nil
        let card = drafts[index]
        do {
            let previous = card.remoteID.map { SavedDraft(id: $0, mirrorID: card.mirrorID) }
            let saved = try await outboxPort.saveDraft(card.inlet, card.draft, replacing: previous)
            guard let now = drafts.firstIndex(where: { $0.id == id }), drafts[now].inlet == card.inlet else {
                try? await outboxPort.deleteDraft(card.inlet, draftID: saved.id)
                return false
            }
            let queued = drafts[now].outboxID
            if let queued, !outboxPort.discard(queued) {
                if saved.id == card.remoteID {
                    drafts[now].mirrorID = saved.mirrorID
                } else {
                    try? await outboxPort.deleteDraft(card.inlet, draftID: saved.id)
                }
                holdForOutbox(now)
                return false
            }
            drafts[now].remoteID = saved.id
            drafts[now].mirrorID = saved.mirrorID
            if queued != nil {
                outbox = outboxPort.outbox
                drafts[now].outboxID = nil
            }
            if drafts[now].state == .saving {
                drafts[now].state = editedWhileSaving.contains(id) ? .edited : .saved(clock())
            }
            keepLocal(id)
            refreshCounts()
            if queued != nil { await refreshOutboxList() }
            return true
        } catch {
            guard let now = drafts.firstIndex(where: { $0.id == id }), drafts[now].inlet == card.inlet else { return false }
            drafts[now].saveFailure = Self.hint(error)
            if drafts[now].state == .saving { drafts[now].state = .edited }
            return false
        }
    }

    private func holdForOutbox(_ index: Int) {
        drafts[index].state = .queuedInOutbox
        outbox = outboxPort.outbox
        reconcileDrafts()
    }

    public func deleteDraft(_ id: UUID) async {
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
        let inlet = drafts[index].inlet
        let remoteID = drafts[index].remoteID
        let mirrorID = drafts[index].mirrorID
        if let remoteID {
            do {
                try await outboxPort.deleteDraft(inlet, draftID: remoteID)
            } catch {
                guard let now = drafts.firstIndex(where: { $0.id == id }) else { return }
                drafts[now].saveFailure = Self.hint(error)
                return
            }
            if let mirrorID { goneDrafts[inlet, default: []].insert(mirrorID) }
            refreshAfterDraftChange(inlet)
        }
        drafts.removeAll { $0.id == id }
        dropLocal(id)
        detach(.draft(id))
    }

    @discardableResult
    public func editDraft(_ messageID: String) async -> UUID? {
        guard let inlet = selectedInlet else { return nil }
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
        var loaded = stored.draft
        if loaded.signed == nil, let block = signatures(inlet)?.block, SignatureEngine.removed(block, from: loaded.body) != nil {
            loaded.signed = block
        }
        let id = add(inlet: inlet, loaded)
        if let index = drafts.firstIndex(where: { $0.id == id }) {
            drafts[index].remoteID = stored.id
            drafts[index].mirrorID = messageID
        }
        keepLocal(id)
        return id
    }

    public func send(_ id: UUID) async {
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
        let card = drafts[index]
        if draftWork[id] != nil || card.state == .saving {
            sendAfterSave.insert(id)
            return
        }
        switch card.state {
        case .sending, .sent, .queuedInOutbox: return
        default: break
        }
        if let refusal = Self.refusal(card.draft) {
            post(refusal)
            return
        }
        if let limit = await mailbox.sendLimit(card.inlet), MessageEngine.encodedSize(card.draft) > limit {
            if let now = drafts.firstIndex(where: { $0.id == id }) { drafts[now].tooLarge = true }
            return
        }
        guard sendHold > .zero, card.outboxID == nil else {
            await deliver(id)
            return
        }
        hold(id, returning: card.state)
    }

    private func hold(_ id: UUID, returning previous: DraftState) {
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
        drafts[index].state = .sending
        keepLocal(id)
        let wait = sendHold
        heldSends[id] = Task { [weak self] in
            try? await Task.sleep(for: wait)
            guard !Task.isCancelled, let self, self.heldSends.removeValue(forKey: id) != nil else { return }
            await self.deliver(id, announce: false)
        }
        post(.outboxSent, undo: { [weak self] in self?.recall(id, to: previous) }, lasts: wait)
    }

    func recall(_ id: UUID, to previous: DraftState) {
        guard let task = heldSends.removeValue(forKey: id) else { return }
        task.cancel()
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
        drafts[index].state = previous
        bring(.draft(id))
    }

    func releaseHeldSends() async {
        let held = heldSends
        heldSends = [:]
        for (id, task) in held {
            task.cancel()
            await deliver(id, announce: false)
        }
    }

    func isHeld(_ id: UUID) -> Bool { heldSends[id] != nil }

    private func deliver(_ id: UUID, announce: Bool = true) async {
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
        let card = drafts[index]
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
            dropLocal(id)
            if let mirrorID = card.mirrorID { goneDrafts[card.inlet, default: []].insert(mirrorID) }
            refreshAfterDraftChange(card.inlet, roles: [.drafts, .sent])
            if announce { post(.outboxSent) }
        case .queued(let outboxID):
            drafts[now].outboxID = outboxID
            drafts[now].state = .queuedInOutbox
            dropLocal(id)
            if drafts[now].draft != card.draft { outboxPort.revise(outboxID, drafts[now].draft) }
            reconcileDrafts()
        }
    }

    static func stillWriting(_ state: DraftState) -> Bool {
        switch state {
        case .idle, .edited, .saving, .saved, .sendFailed: true
        case .sending, .sent, .queuedInOutbox: false
        }
    }

    static func refusal(_ draft: Draft) -> ToastKind? {
        let recipients = [draft.to, draft.cc, draft.bcc].compactMap { $0 }
        if recipients.allSatisfy({ AddressListParser.split($0).isEmpty }) { return .recipientMissing }
        if draft.subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .subjectMissing }
        return nil
    }

    public func refuseSend(_ id: UUID) {
        guard let card = draft(id) else { return }
        post(Self.refusal(card.draft) ?? .recipientMissing)
    }

    func reconcileDrafts() {
        for index in drafts.indices {
            guard drafts[index].state == .queuedInOutbox, let outboxID = drafts[index].outboxID else { continue }
            guard let item = outbox.first(where: { $0.id == outboxID }) else {
                drafts[index].state = .sent
                dropLocal(drafts[index].id)
                if let mirrorID = drafts[index].mirrorID { goneDrafts[drafts[index].inlet, default: []].insert(mirrorID) }
                refreshAfterDraftChange(drafts[index].inlet, roles: [.drafts, .sent])
                continue
            }
            if let current = item.draftID { drafts[index].remoteID = current }
            if let mirror = item.mirrorID, mirror != drafts[index].mirrorID {
                if let old = drafts[index].mirrorID { goneDrafts[drafts[index].inlet, default: []].insert(old) }
                drafts[index].mirrorID = mirror
            }
            switch item.state {
            case .failed(let hint), .unverified(let hint): drafts[index].state = .sendFailed(hint)
            case .waiting, .checking, .sending, .planned, .missed: drafts[index].state = .queuedInOutbox
            }
        }
    }

    func add(inlet: Inlet.ID, _ draft: Draft, signing: Bool = false) -> UUID {
        var draft = draft
        if draft.from == nil { draft.from = mailbox.sender(inlet) }
        if signing { draft.resign(to: signatures(inlet)) }
        let card = OpenDraft(id: UUID(), inlet: inlet, draft: draft, state: .idle, outboxID: nil, remoteID: nil,
                             saveFailure: nil)
        drafts.append(card)
        attach(.draft(card.id))
        keepLocal(card.id)
        return card.id
    }

    func accountAddress(_ inlet: Inlet.ID) -> String {
        accounts.first { $0.id == inlet }?.account.lowercased() ?? ""
    }

    func quoted(_ id: String, summary: MessageSummary) async -> String {
        let text = await messageText(id) ?? summary.snippet
        let words = quoteTexts()
        let head = Quoting.attribution(summary.from.isEmpty ? summary.fromRaw : summary.from, at: summary.receivedAt,
                                       dated: words.dated, undated: words.undated, locale: words.locale)
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

    public func dismissTooLarge(_ id: UUID) {
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
        drafts[index].tooLarge = false
    }

    public func removeAttachment(_ id: UUID, at index: Int) {
        edit(id) { draft in
            guard draft.attachments.indices.contains(index) else { return }
            draft.attachments.remove(at: index)
        }
    }
}
