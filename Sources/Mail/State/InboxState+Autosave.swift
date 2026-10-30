import Foundation
import Hub

extension InboxState {
    func keepLocal(_ id: UUID) {
        guard let card = draft(id) else { return }
        if Self.blank(card.draft), card.remoteID == nil {
            outboxPort.dropKept(id)
            return
        }
        outboxPort.keep(KeptDraft(id: id, inlet: card.inlet, draft: card.draft, remoteID: card.remoteID,
                                  mirrorID: card.mirrorID, updatedAt: clock()))
    }

    func dropLocal(_ id: UUID) {
        stopAutosave(id)
        outboxPort.dropKept(id)
    }

    func stopAutosave(_ id: UUID) {
        autosaveSerials[id] = nil
    }

    func scheduleAutosave(_ id: UUID) {
        let mine = (autosaveSerials[id] ?? 0) + 1
        autosaveSerials[id] = mine
        let pause = autosavePause
        Task { [weak self] in
            try? await Task.sleep(for: pause)
            guard let self, self.autosaveSerials[id] == mine else { return }
            await self.autosave(id)
        }
        guard autosaveTicking.insert(id).inserted else { return }
        let interval = autosaveInterval
        Task { [weak self] in
            while true {
                try? await Task.sleep(for: interval)
                guard let self else { return }
                guard self.autosaveSerials[id] != nil,
                      let state = self.draft(id)?.state, state == .edited || state == .saving else {
                    self.autosaveTicking.remove(id)
                    return
                }
                await self.autosave(id)
            }
        }
    }

    func autosave(_ id: UUID) async {
        guard let card = draft(id), card.state == .edited, !Self.blank(card.draft) else { return }
        await save(id)
    }

    func restoreKeptDrafts() {
        let known = Set(accounts.map(\.id))
        for kept in outboxPort.keptDrafts where known.contains(kept.inlet) && draft(kept.id) == nil {
            let card = OpenDraft(id: kept.id, inlet: kept.inlet, draft: kept.draft, state: .edited, outboxID: nil,
                                 remoteID: kept.remoteID, mirrorID: kept.mirrorID, saveFailure: nil)
            drafts.append(card)
            let ref = CardRef.draft(card.id)
            if kept.inlet == selectedInlet {
                attach(ref)
            } else {
                var shelf = parked[kept.inlet] ?? ParkedMailbox()
                shelf.stack.append(ref)
                shelf.front = ref
                parked[kept.inlet] = shelf
            }
            scheduleAutosave(card.id)
        }
    }

    public func flushDrafts(within limit: Duration) async {
        let pending = drafts.filter { $0.state == .edited && !Self.blank($0.draft) }.map(\.id)
        guard !pending.isEmpty || !heldSends.isEmpty else { return }
        for id in pending { keepLocal(id) }
        let finished = AsyncStream<Void>.makeStream()
        Task { @MainActor in
            await self.releaseHeldSends()
            for id in pending { await self.autosave(id) }
            finished.continuation.yield()
        }
        Task {
            try? await Task.sleep(for: limit)
            finished.continuation.yield()
        }
        for await _ in finished.stream { break }
    }

    public func flushDrafts() async {
        await flushDrafts(within: AutosaveEngine.quitLimit)
    }
}
