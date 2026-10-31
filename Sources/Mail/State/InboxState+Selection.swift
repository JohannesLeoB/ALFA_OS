import Hub

extension InboxState {
    public var pickedInList: [String] {
        let listed = Set(rows.map(\.id))
        return picked.filter { listed.contains($0) }
    }

    public var picking: Bool { !pickedInList.isEmpty }

    public func pick(_ id: String) {
        if selectedFolder == Folder.outboxID { return }
        if let index = picked.firstIndex(of: id) { picked.remove(at: index) } else { picked.append(id) }
    }

    public func pickAllToggle() {
        if selectedFolder == Folder.outboxID { return }
        let all = rows.map(\.id)
        picked = pickedInList.count == all.count ? [] : all
    }

    public func clearPicked() {
        picked = []
    }

    public func pickRange(to id: String) {
        if selectedFolder == Folder.outboxID { return }
        let order = rows.map(\.id)
        guard let end = order.firstIndex(of: id) else { return }
        guard let anchor = pickedInList.last.flatMap({ order.firstIndex(of: $0) }) else {
            pick(id)
            return
        }
        for item in order[min(anchor, end)...max(anchor, end)] where !picked.contains(item) { picked.append(item) }
    }

    public func bulk(_ kind: BulkAction) async {
        let list = pickedInList.compactMap { summary($0) }
        guard !list.isEmpty, kind != .trash || !list.contains(where: { inTrash($0.id) }) else { return }
        switch kind {
        case .read:
            let anyUnread = list.contains { !$0.flags.contains(.seen) }
            let inlet = selectedInlet
            var failed: [String] = []
            for item in list {
                if await !setFlag(item.id, .seen, on: anyUnread, in: inlet, quiet: true) { failed.append(item.id) }
            }
            picked = []
            if failed.isEmpty {
                post(.bulkRead(count: list.count, read: anyUnread))
            } else {
                post(.flagFailed, undo: { [weak self] in
                    self?.picked = failed
                    await self?.bulk(.read)
                })
            }
        case .archive, .trash:
            guard let inlet = selectedInlet else { return }
            let origin = selectedFolder
            let lifted = lift(list.map(\.id), in: inlet)
            let opening = reopen(lifted.next)
            picked = []
            var moved: [(id: String, landed: String?, inlet: Inlet.ID, origin: String?)] = []
            var failed: [(summary: MessageSummary, index: Int)] = []
            for entry in list {
                do {
                    let landed: String?
                    if kind == .archive {
                        landed = try await mailbox.archive(inlet, messageID: entry.id)
                    } else {
                        landed = try await mailbox.trash(inlet, messageID: entry.id)
                    }
                    moved.append((entry.id, landed, inlet, Self.serverFolder(origin, of: entry)))
                } catch {
                    failed.append(lifted.entries.first { $0.summary.id == entry.id } ?? (entry, summaries.count))
                }
            }
            putBack(failed, in: inlet, folder: origin)
            refreshCounts()
            await opening?.value
            if !failed.isEmpty {
                let retry = failed.map(\.summary.id)
                post(kind == .archive ? .archiveFailed : .deleteFailed, undo: { [weak self] in
                    self?.picked = retry
                    await self?.bulk(kind)
                })
                return
            }
            let entries = moved
            let undo: @MainActor () async -> Void = { [weak self] in
                await self?.restore(entries, fromTrash: kind == .trash)
            }
            let undoable = moved.contains { $0.landed != nil }
            post(kind == .archive ? .bulkArchived(count: moved.count) : .bulkTrashed(count: moved.count), undo: undoable ? undo : nil)
        }
    }
}
