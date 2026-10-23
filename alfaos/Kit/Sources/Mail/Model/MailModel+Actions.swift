import Foundation
import Hub
import enum AlfaServices.MailFolderRole

enum MailMove: Equatable {
    case archive
    case trash
    case spam
    case folder(String)
}

extension MailModel {
    public func archive(_ id: String, undoable: Bool = false) async { await relocate(id, .archive, undoable: undoable) }

    public func trash(_ id: String, undoable: Bool = true, fromMenu: Bool = false) async {
        await relocate(id, .trash, undoable: undoable, toast: fromMenu ? .inTrash : .trashed)
    }

    public func markSpam(_ id: String) async { await relocate(id, .spam) }

    public func move(_ id: String, toFolder folder: String) async { await relocate(id, .folder(folder)) }

    func checkPurge() async {
        guard let inlet = selectedInlet, currentFolder?.role == .trash else { return }
        await engine.checkPurge(inlet)
        purgeChecks += 1
    }

    public func canPurge(_ id: String) -> Bool {
        _ = purgeChecks
        guard let inlet = cardInlet(id) ?? selectedInlet else { return false }
        return engine.canPurge(inlet)
    }

    public func purge(_ id: String) async {
        guard let inlet = cardInlet(id) ?? selectedInlet else { return }
        do {
            try await engine.purge(inlet, messageID: id)
        } catch {
            actionFailures[id] = Self.hint(error)
            return
        }
        actionFailures[id] = nil
        summaries.removeAll { $0.id == id }
        close(id)
        refreshCounts()
        post(.purged)
    }

    func relocate(_ id: String, _ move: MailMove, undoable: Bool = false, toast: MailToastKind = .trashed) async {
        guard let inlet = cardInlet(id) ?? selectedInlet else { return }
        let origin = selectedFolder
        let landed: String?
        do {
            switch move {
            case .archive: landed = try await engine.archive(inlet, messageID: id)
            case .trash: landed = try await engine.trash(inlet, messageID: id)
            case .spam:
                try await engine.markSpam(inlet, messageID: id)
                landed = nil
            case .folder(let folder): landed = try await engine.move(inlet, messageID: id, toFolder: folder)
            }
        } catch {
            actionFailures[id] = Self.hint(error)
            return
        }
        actionFailures[id] = nil
        let staysListed = move == .archive && folders.first { $0.id == selectedFolder }?.role == .all
        if !staysListed { summaries.removeAll { $0.id == id } }
        close(id)
        refreshCounts()
        var undo: (@MainActor () async -> Void)?
        if undoable, let landed {
            undo = { [weak self] in
                guard let self, let origin else { return }
                do throws(HubError) {
                    try await self.engine.move(inlet, messageID: landed, toFolder: origin)
                } catch {
                    self.actionFailures[id] = Self.hint(error)
                    return
                }
                await self.loadSelection()
            }
        }
        switch move {
        case .archive: post(.archived, undo: undo)
        case .trash: post(toast, undo: undo)
        case .spam, .folder: break
        }
    }

    public func attachmentData(_ id: String, attachmentID: String) async -> Data? {
        guard let inlet = cardInlet(id) ?? selectedInlet else { return nil }
        do {
            let data = try await engine.attachment(inlet, messageID: id, attachmentID: attachmentID)
            actionFailures[id] = nil
            return data
        } catch {
            actionFailures[id] = Self.hint(error)
            return nil
        }
    }

    public func loadThread(_ id: String) async {
        guard let inlet = cardInlet(id) ?? selectedInlet, let summary = summary(id) else { return }
        let threadID = summary.threadID.isEmpty ? id : summary.threadID
        do {
            let messages = try await engine.thread(inlet, messageID: id, threadID: threadID)
            actionFailures[id] = nil
            update(id) { $0.conversation = messages }
        } catch {
            actionFailures[id] = Self.hint(error)
        }
    }
}
