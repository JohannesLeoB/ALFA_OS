import Foundation
import Hub

extension InboxState {
    func archive(_ id: String, undoable: Bool = false) async { await relocate(id, .archive, undoable: undoable) }

    func trash(_ id: String, undoable: Bool = true, fromMenu: Bool = false) async {
        await relocate(id, .trash, undoable: undoable, toast: fromMenu ? .inTrash : .trashed)
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
            return
        }
        if selectedInlet == inlet { summaries.removeAll { $0.id == id } }
        drop(id, in: inlet)
        refreshCounts()
        post(.purged)
    }

    func relocate(_ id: String, _ move: MoveTarget, undoable: Bool = false, toast: ToastKind = .trashed) async {
        guard let inlet = selectedInlet else { return }
        let origin = selectedFolder
        let landed: String?
        do {
            switch move {
            case .archive: landed = try await mailbox.archive(inlet, messageID: id)
            case .trash: landed = try await mailbox.trash(inlet, messageID: id)
            case .spam:
                try await mailbox.markSpam(inlet, messageID: id)
                landed = nil
            }
        } catch {
            return
        }
        let staysListed = move == .archive && folders.first { $0.id == selectedFolder }?.role == .all
        if !staysListed && selectedInlet == inlet { summaries.removeAll { $0.id == id } }
        drop(id, in: inlet)
        refreshCounts()
        var undo: (@MainActor () async -> Void)?
        if undoable, let landed {
            undo = { [weak self] in
                guard let self, let origin else { return }
                await self.restore([(id, landed, inlet)], to: origin)
            }
        }
        switch move {
        case .archive: post(.archived, undo: undo)
        case .trash: post(toast, undo: undo)
        case .spam: break
        }
    }

    public var offersOriginal: Bool {
        selectedInlet.map { mailbox.offersSource($0) } ?? false
    }

    public func original(_ id: String) async -> String? {
        guard let inlet = selectedInlet, let data = try? await mailbox.source(inlet, messageID: id) else { return nil }
        return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
    }

    public func moveTargets(_ id: String) -> [Folder] {
        let current = Set(summary(id)?.folderIDs ?? []).union([selectedFolder].compactMap { $0 })
        return sortedFolders.filter { !current.contains($0.id) && !Self.fixedRoles.contains($0.role) }
    }

    func move(_ id: String, to folder: String) async {
        guard let inlet = selectedInlet else { return }
        let origin = selectedFolder
        let landed: String?
        do {
            landed = try await mailbox.move(inlet, messageID: id, toFolder: folder)
        } catch {
            return
        }
        if selectedInlet == inlet { summaries.removeAll { $0.id == id } }
        drop(id, in: inlet)
        refreshCounts()
        var undo: (@MainActor () async -> Void)?
        if let landed, let origin {
            undo = { [weak self] in await self?.restore([(id, landed, inlet)], to: origin) }
        }
        post(.moved, undo: undo)
    }

    private static let fixedRoles: Set<FolderRole> = [.drafts, .sent, .starred, .all]

    func restore(_ moved: [(id: String, landed: String?, inlet: Inlet.ID)], to origin: String) async {
        for entry in moved {
            guard let landed = entry.landed else { continue }
            _ = try? await mailbox.move(entry.inlet, messageID: landed, toFolder: origin)
        }
        await loadSelection()
    }

    public func attachmentData(_ id: String, attachmentID: String) async -> Data? {
        guard let inlet = selectedInlet else { return nil }
        return try? await mailbox.attachment(inlet, messageID: id, attachmentID: attachmentID)
    }

    func loadThread(_ id: String) async {
        guard let inlet = selectedInlet, let summary = summary(id) else { return }
        let threadID = summary.threadID.isEmpty ? id : summary.threadID
        if let messages = try? await mailbox.thread(inlet, messageID: id, threadID: threadID) {
            update(id, in: inlet) { $0.conversation = messages }
        }
    }
}
