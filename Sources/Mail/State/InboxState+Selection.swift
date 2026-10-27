import Hub

extension InboxState {
    public var pickedInList: [String] {
        let listed = Set(rows.map(\.id))
        return picked.filter { listed.contains($0) }
    }

    public var picking: Bool { !pickedInList.isEmpty }

    public func pick(_ id: String) {
        if let index = picked.firstIndex(of: id) { picked.remove(at: index) } else { picked.append(id) }
    }

    public func pickAllToggle() {
        let all = rows.map(\.id)
        picked = pickedInList.count == all.count ? [] : all
    }

    public func clearPicked() {
        picked = []
    }

    public func bulk(_ kind: BulkAction) async {
        let list = pickedInList.compactMap { summary($0) }
        guard !list.isEmpty else { return }
        switch kind {
        case .read:
            let anyUnread = list.contains { !$0.flags.contains(.seen) }
            for item in list { await setFlag(item.id, .seen, on: anyUnread) }
            picked = []
            post(.bulkRead(count: list.count, read: anyUnread))
        case .archive, .trash:
            let origin = selectedFolder
            var moved: [(id: String, landed: String?, inlet: Inlet.ID)] = []
            for item in list {
                guard let inlet = cardInlet(item.id) ?? selectedInlet else { continue }
                do {
                    let landed: String?
                    if kind == .archive {
                        landed = try await mailbox.archive(inlet, messageID: item.id)
                    } else {
                        landed = try await mailbox.trash(inlet, messageID: item.id)
                    }
                    moved.append((item.id, landed, inlet))
                } catch {
                    continue
                }
            }
            let gone = Set(moved.map(\.id))
            summaries.removeAll { gone.contains($0.id) }
            for id in gone { close(id) }
            picked = []
            refreshCounts()
            let entries = moved
            let undo: @MainActor () async -> Void = { [weak self] in
                guard let self, let origin else { return }
                await self.restore(entries, to: origin)
            }
            let undoable = moved.contains { $0.landed != nil }
            post(kind == .archive ? .bulkArchived(count: moved.count) : .bulkTrashed(count: moved.count), undo: undoable ? undo : nil)
        }
    }
}
