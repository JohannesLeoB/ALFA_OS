import Foundation
import Hub
import enum AlfaServices.MailFlag

public enum MailBulk: Equatable, Sendable {
    case read
    case archive
    case trash
}

extension MailModel {
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

    public func bulk(_ kind: MailBulk) async {
        let ids = pickedInList
        let list = ids.compactMap { summary($0) }
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
                        landed = try await engine.archive(inlet, messageID: item.id)
                    } else {
                        landed = try await engine.trash(inlet, messageID: item.id)
                    }
                    moved.append((item.id, landed, inlet))
                } catch {
                    actionFailures[item.id] = Self.hint(error)
                }
            }
            let gone = Set(moved.map(\.id))
            summaries.removeAll { gone.contains($0.id) }
            for id in gone { close(id) }
            picked = []
            refreshCounts()
            let undo: @MainActor () async -> Void = { [weak self] in
                guard let self, let origin else { return }
                for entry in moved {
                    guard let landed = entry.landed else { continue }
                    do throws(HubError) {
                        try await self.engine.move(entry.inlet, messageID: landed, toFolder: origin)
                    } catch {
                        self.actionFailures[entry.id] = Self.hint(error)
                    }
                }
                await self.loadSelection()
            }
            let undoable = moved.contains { $0.landed != nil }
            post(kind == .archive ? .bulkArchived(count: moved.count) : .bulkTrashed(count: moved.count), undo: undoable ? undo : nil)
        }
    }
}
