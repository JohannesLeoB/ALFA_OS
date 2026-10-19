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
            var moved: [(String, Inlet.ID)] = []
            for item in list {
                guard let inlet = cardInlet(item.id) ?? selectedInlet else { continue }
                do {
                    if kind == .archive {
                        try await engine.archive(inlet, messageID: item.id)
                    } else {
                        try await engine.trash(inlet, messageID: item.id)
                    }
                    moved.append((item.id, inlet))
                } catch {
                    actionFailures[item.id] = Self.hint(error)
                }
            }
            let gone = Set(moved.map(\.0))
            summaries.removeAll { gone.contains($0.id) }
            for id in gone { close(id) }
            picked = []
            refreshCounts()
            let undo: @MainActor () async -> Void = { [weak self] in
                guard let self, let origin else { return }
                for (id, inlet) in moved { try? await self.engine.move(inlet, messageID: id, toFolder: origin) }
                await self.loadSelection()
            }
            post(kind == .archive ? .bulkArchived(count: moved.count) : .bulkTrashed(count: moved.count), undo: undo)
        }
    }
}
