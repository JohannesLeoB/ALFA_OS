import Foundation
import Hub

extension InboxState {
    public func unsent(_ inlet: Inlet.ID) -> Int {
        outbox.filter { $0.inlet == inlet }.count
    }

    var hasUnsent: Bool {
        guard let inlet = selectedInlet else { return false }
        return outbox.contains { $0.inlet == inlet }
    }

    func showOutbox() {
        generation += 1
        summaries = outboxSummaries()
        mirrorSerial += 1
        phase = .settled
    }

    func outboxSummaries() -> [MessageSummary] {
        outbox.filter { $0.inlet == selectedInlet }.map { item in
            MessageSummary(id: item.id.uuidString, subject: item.draft.subject, from: "", toRaw: item.draft.to ?? "",
                           snippet: item.draft.body, flags: [.seen])
        }
    }

    func refreshOutboxList() async {
        guard selectedFolder == Folder.outboxID else { return }
        if hasUnsent {
            summaries = outboxSummaries()
            mirrorSerial += 1
        } else if let inbox = sortedFolders.first(where: { $0.role == .inbox })?.id {
            await selectFolder(inbox)
        }
    }

    func queued(_ rowID: String) -> OutboxItem? {
        outbox.first { $0.id.uuidString == rowID && $0.inlet == selectedInlet }
    }

    public func openQueued(_ rowID: String) {
        guard let inlet = selectedInlet, let item = queued(rowID) else { return }
        let hint: Hint
        switch item.state {
        case .failed(let value), .unverified(let value): hint = value
        case .waiting, .checking, .sending: return
        }
        if let open = drafts.first(where: { $0.outboxID == item.id }) {
            attach(.draft(open.id))
            return
        }
        let card = OpenDraft(id: UUID(), inlet: inlet, draft: item.draft, state: .sendFailed(hint), outboxID: item.id,
                             remoteID: item.draftID, mirrorID: item.mirrorID, saveFailure: nil,
                             tooLarge: hint.text == MessageTextKey.tooLarge.rawValue)
        drafts.append(card)
        attach(.draft(card.id))
    }

    public func resendQueued(_ rowID: String) async {
        guard let item = queued(rowID) else { return }
        let outcome = await outboxPort.resend(item.id, item.draft, draftID: item.draftID)
        outbox = outboxPort.outbox
        if outcome == .sent { post(.outboxSent) }
        reconcileDrafts()
        await refreshOutboxList()
    }

    public func confirmQueued(_ rowID: String) async {
        guard let item = queued(rowID) else { return }
        await outboxPort.confirm(item.id)
        let delivered = !outboxPort.outbox.contains { $0.id == item.id }
        outbox = outboxPort.outbox
        if delivered { post(.outboxSent) }
        reconcileDrafts()
        await refreshOutboxList()
    }

    public func discardQueued(_ rowID: String) async {
        guard let item = queued(rowID) else { return }
        let removed = outboxPort.discard(item.id)
        outbox = outboxPort.outbox
        if removed {
            for index in drafts.indices where drafts[index].outboxID == item.id { drafts[index].outboxID = nil }
        }
        await refreshOutboxList()
    }
}
