import Foundation
import Hub

extension InboxState {
    func archive(_ id: String, undoable: Bool = true) async { await relocate(id, .archive, undoable: undoable) }

    func trash(_ id: String, undoable: Bool = true, fromMenu: Bool = false) async {
        guard !inTrash(id) else { return }
        await relocate(id, .trash, undoable: undoable, toast: fromMenu ? .inTrash : .trashed)
    }

    public func inTrash(_ id: String) -> Bool {
        guard let trash = folders.first(where: { $0.role == .trash })?.id else { return false }
        return summary(id)?.folderIDs.contains(trash) == true || (selectedFolder == trash && summaries.contains { $0.id == id })
    }

    func markSpam(_ id: String) async { await relocate(id, .spam) }

    func checkPurge() async {
        guard let inlet = selectedInlet, currentFolder?.role == .trash else { return }
        await mailbox.checkPurge(inlet)
        purgeChecks += 1
    }

    public func canPurge(_ id: String) -> Bool {
        _ = purgeChecks
        guard let inlet = selectedInlet else { return false }
        return mailbox.canPurge(inlet)
    }

    func purge(_ id: String) async {
        guard let inlet = selectedInlet else { return }
        do {
            try await mailbox.purge(inlet, messageID: id)
        } catch {
            post(.deleteFailed, undo: { [weak self] in await self?.purge(id) })
            return
        }
        if selectedInlet == inlet { summaries.removeAll { $0.id == id } }
        drop(id, in: inlet)
        refreshCounts()
        post(.purged)
    }

    static func relocateFailure(_ move: MoveTarget) -> ToastKind {
        switch move {
        case .archive: .archiveFailed
        case .trash: .deleteFailed
        case .spam: .moveFailed
        }
    }

    func relocate(_ id: String, _ move: MoveTarget, undoable: Bool = false, toast: ToastKind = .trashed) async {
        guard let inlet = selectedInlet, let held = summary(id) else { return }
        let origin = Self.serverFolder(selectedFolder, of: held)
        let staysListed = move == .archive && folders.first { $0.id == selectedFolder }?.role == .all
        let lifted = lift([id], in: inlet, keepListed: staysListed)
        let opening = reopen(lifted.next)
        let landed: String?
        do {
            switch move {
            case .archive: landed = try await mailbox.archive(inlet, messageID: id)
            case .trash: landed = try await mailbox.trash(inlet, messageID: id)
            case .spam: landed = try await mailbox.markSpam(inlet, messageID: id)
            }
        } catch {
            putBack(lifted.entries, in: inlet, folder: selectedFolder)
            await opening?.value
            post(Self.relocateFailure(move), undo: { [weak self] in await self?.relocate(id, move, undoable: undoable, toast: toast) })
            return
        }
        refreshCounts()
        var undo: (@MainActor () async -> Void)?
        if undoable, let landed, let origin {
            undo = { [weak self] in await self?.restore([(id, landed, inlet, origin)]) }
        }
        switch move {
        case .archive: post(.archived, undo: undo)
        case .trash: post(toast, undo: undo)
        case .spam: post(.moved, undo: undo)
        }
        await opening?.value
    }

    func lift(_ ids: [String], in inlet: Inlet.ID, keepListed: Bool = false) -> (entries: [(summary: MessageSummary, index: Int)], next: String?) {
        let gone = Set(ids)
        var next: String?
        if selectedInlet == inlet, let current = selectedMessage, gone.contains(current) {
            let order = rows.map(\.id)
            if let position = order.firstIndex(of: current) {
                next = order[position...].first { !gone.contains($0) } ?? order[..<position].last { !gone.contains($0) }
            }
        }
        var entries: [(summary: MessageSummary, index: Int)] = []
        if selectedInlet == inlet && !keepListed {
            for (index, item) in summaries.enumerated() where gone.contains(item.id) { entries.append((item, index)) }
            summaries.removeAll { gone.contains($0.id) }
        }
        for id in ids { drop(id, in: inlet) }
        return (entries, next)
    }

    func putBack(_ entries: [(summary: MessageSummary, index: Int)], in inlet: Inlet.ID, folder: String?) {
        guard selectedInlet == inlet, selectedFolder == folder else { return }
        for entry in entries.sorted(by: { $0.index < $1.index }) where !summaries.contains(where: { $0.id == entry.summary.id }) {
            summaries.insert(entry.summary, at: min(entry.index, summaries.count))
        }
    }

    func reopen(_ id: String?) -> Task<Void, Never>? {
        guard let id else { return nil }
        return Task { [weak self] in await self?.open(id) }
    }

    public var offersOriginal: Bool {
        selectedInlet.map { mailbox.offersSource($0) } ?? false
    }

    public var offersSpam: Bool {
        folderActions && folders.contains { $0.role == .spam }
    }

    public func original(_ id: String) async -> String? {
        guard let inlet = selectedInlet else { return nil }
        do {
            let data = try await mailbox.source(inlet, messageID: id)
            return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        } catch {
            post(.readFailed)
            return nil
        }
    }

    public func moveTargets(_ id: String) -> [Folder] {
        let current = Set(summary(id)?.folderIDs ?? []).union([selectedFolder].compactMap { $0 })
        return sortedFolders.filter { !current.contains($0.id) && !Self.fixedRoles.contains($0.role) }
    }

    func move(_ id: String, to folder: String) async {
        guard let inlet = selectedInlet, let held = summary(id) else { return }
        let origin = Self.serverFolder(selectedFolder, of: held)
        let lifted = lift([id], in: inlet)
        let opening = reopen(lifted.next)
        let landed: String?
        do {
            landed = try await mailbox.move(inlet, messageID: id, toFolder: folder)
        } catch {
            putBack(lifted.entries, in: inlet, folder: selectedFolder)
            await opening?.value
            post(.moveFailed, undo: { [weak self] in await self?.move(id, to: folder) })
            return
        }
        refreshCounts()
        var undo: (@MainActor () async -> Void)?
        if let landed, let origin {
            undo = { [weak self] in await self?.restore([(id, landed, inlet, origin)]) }
        }
        post(.moved, undo: undo)
        await opening?.value
    }

    private static let fixedRoles: Set<FolderRole> = [.drafts, .sent, .starred, .all]

    static func serverFolder(_ selected: String?, of summary: MessageSummary) -> String? {
        guard let selected, selected.hasPrefix("local:") else { return selected }
        return summary.folderIDs.first { !$0.hasPrefix("local:") }
    }

    func restore(_ moved: [(id: String, landed: String?, inlet: Inlet.ID, origin: String?)]) async {
        var failed = false
        for entry in moved {
            guard let landed = entry.landed, let target = entry.origin else { continue }
            do {
                _ = try await mailbox.move(entry.inlet, messageID: landed, toFolder: target)
            } catch {
                failed = true
            }
        }
        await loadSelection()
        if failed { post(.moveFailed) }
    }

    public func attachmentData(_ id: String, attachmentID: String) async -> Data? {
        guard let inlet = selectedInlet else { return nil }
        do {
            return try await mailbox.attachment(inlet, messageID: id, attachmentID: attachmentID)
        } catch {
            post(.attachmentFailed)
            return nil
        }
    }

    func loadThread(_ id: String) async {
        guard let inlet = selectedInlet, let summary = summary(id) else { return }
        let threadID = summary.threadID.isEmpty ? id : summary.threadID
        do {
            let messages = try await mailbox.thread(inlet, messageID: id, threadID: threadID)
            update(id, in: inlet) { $0.conversation = messages }
        } catch {
            post(.threadFailed, undo: { [weak self] in await self?.loadThread(id) })
        }
    }
}
