import Foundation
import Hub

extension InboxState {
    public func unsent(_ inlet: Inlet.ID) -> Int {
        outbox.filter { $0.inlet == inlet }.count
    }

    var hasUnsent: Bool {
        guard let inlet = selectedInlet else { return false }
        return outbox.contains { $0.inlet == inlet && $0.state.plannedAt == nil }
    }

    var hasPlanned: Bool {
        guard let inlet = selectedInlet else { return false }
        return outbox.contains { $0.inlet == inlet && $0.state.plannedAt != nil }
    }

    func plannedDrafts(_ inlet: Inlet.ID) -> Set<String> {
        Set(outbox.filter { $0.inlet == inlet && $0.state.plannedAt != nil }.compactMap(\.mirrorID))
    }

    func showOutbox() {
        generation += 1
        summaries = outboxSummaries()
        mirrorSerial += 1
        phase = .settled
    }

    func outboxSummaries() -> [MessageSummary] {
        let later = selectedFolder == Folder.laterID
        let listed = outbox.filter { $0.inlet == selectedInlet && ($0.state.plannedAt != nil) == later }
        let ordered = later ? listed.sorted { ($0.state.plannedAt ?? .distantPast) < ($1.state.plannedAt ?? .distantPast) } : listed
        return ordered.map { item in
            MessageSummary(id: item.id.uuidString, subject: item.draft.subject, from: "", toRaw: item.draft.to ?? "",
                           snippet: item.draft.body, flags: [.seen])
        }
    }

    func outboxChanged() async {
        let remaining = Set(outboxPort.outbox.map(\.id))
        outbox = outboxPort.outbox
        for (id, entry) in plannedMirrors where !remaining.contains(id) {
            plannedMirrors[id] = nil
            goneDrafts[entry.inlet, default: []].insert(entry.mirrorID)
            refreshAfterDraftChange(entry.inlet, roles: [.drafts, .sent])
        }
        notePlanned()
        reconcileDrafts()
        await refreshOutboxList()
    }

    func notePlanned() {
        for item in outbox where item.state.plannedAt != nil {
            if let mirrorID = item.mirrorID { plannedMirrors[item.id] = (item.inlet, mirrorID) }
        }
    }

    func refreshOutboxList() async {
        guard Folder.queues(selectedFolder) else { return }
        let later = selectedFolder == Folder.laterID
        if later ? hasPlanned : hasUnsent {
            summaries = outboxSummaries()
            mirrorSerial += 1
        } else if let target = sortedFolders.first(where: { $0.role == (later ? .sent : .inbox) })?.id
                    ?? sortedFolders.first(where: { $0.role == .inbox })?.id {
            await selectFolder(target)
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
        case .waiting, .checking, .sending, .planned, .missed: return
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

    public var planChoices: [Date] { Self.planChoices(now: clock()) }

    static func planChoices(now: Date, calendar: Calendar = .current) -> [Date] {
        var result: [Date] = []
        if let evening = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: now), evening > now {
            result.append(evening)
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)),
           let morning = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: tomorrow) {
            result.append(morning)
        }
        let monday = DateComponents(hour: 8, minute: 0, weekday: 2)
        var next = calendar.nextDate(after: now, matching: monday, matchingPolicy: .nextTime)
        if let found = next, result.contains(found) {
            next = calendar.nextDate(after: found, matching: monday, matchingPolicy: .nextTime)
        }
        if let next { result.append(next) }
        return result
    }

    public func pickPlan(_ id: UUID) {
        planning = id
    }

    public func cancelPlan() {
        planning = nil
    }

    public func plan(_ id: UUID, at date: Date) async {
        await settle(id)
        guard let card = draft(id), card.outboxID == nil, date > clock() else { return }
        switch card.state {
        case .sending, .sent, .queuedInOutbox: return
        default: break
        }
        if let refusal = Self.refusal(card.draft) {
            post(refusal)
            return
        }
        let item = outboxPort.plan(card.inlet, card.draft, draftID: card.remoteID, mirrorID: card.mirrorID, at: date)
        outbox = outboxPort.outbox
        notePlanned()
        if planning == id { planning = nil }
        detach(.draft(id))
        drafts.removeAll { $0.id == id }
        dropLocal(id)
        post(.planned(date), undo: { [weak self] in _ = await self?.editPlanned(item.uuidString) })
    }

    @discardableResult
    public func editPlanned(_ rowID: String) async -> UUID? {
        guard let item = unplanned(rowID) else { return nil }
        await leaveLater(to: .drafts)
        let id = restore(item)
        attach(.draft(id))
        scheduleAutosave(id)
        return id
    }

    public func unplan(_ rowID: String) async {
        guard let item = unplanned(rowID) else { return }
        await leaveLater(to: .drafts)
        let id = restore(item)
        await save(id)
        if case .saved = draft(id)?.state {
            dropLocal(id)
            post(.inDrafts)
        } else {
            attach(.draft(id))
        }
    }

    public func sendPlannedNow(_ rowID: String) async {
        guard let item = outbox.first(where: { $0.id.uuidString == rowID }), item.state.plannedAt != nil else { return }
        let outcome = await outboxPort.sendNow(item.id)
        await outboxChanged()
        if outcome == .sent { post(.outboxSent) }
    }

    private func unplanned(_ rowID: String) -> OutboxItem? {
        guard let id = outbox.first(where: { $0.id.uuidString == rowID })?.id, let item = outboxPort.unplan(id) else { return nil }
        plannedMirrors[id] = nil
        outbox = outboxPort.outbox
        return item
    }

    private func restore(_ item: OutboxItem) -> UUID {
        if let mirrorID = item.mirrorID { goneDrafts[item.inlet]?.remove(mirrorID) }
        let card = OpenDraft(id: UUID(), inlet: item.inlet, draft: item.draft, state: .edited, outboxID: nil,
                             remoteID: item.draftID, mirrorID: item.mirrorID, saveFailure: nil)
        drafts.append(card)
        keepLocal(card.id)
        return card.id
    }

    private func leaveLater(to role: FolderRole) async {
        guard selectedFolder == Folder.laterID else { return }
        if hasPlanned {
            summaries = outboxSummaries()
            mirrorSerial += 1
        } else if let target = sortedFolders.first(where: { $0.role == role })?.id {
            await selectFolder(target)
        }
    }
}

public enum PlanDay: Equatable, Sendable {
    case near
    case week
    case later

    public static func of(_ date: Date, now: Date, calendar: Calendar = .current) -> PlanDay {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
        if days <= 1 { return .near }
        return days < 7 ? .week : .later
    }
}
