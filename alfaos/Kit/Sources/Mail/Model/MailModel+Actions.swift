import Foundation
import Hub
import enum MykilosServices.MailFolderRole

enum MailMove: Equatable {
    case archive
    case trash
    case spam
    case folder(String)
}

extension MailModel {
    public func archive(_ id: String) async { await relocate(id, .archive) }

    public func trash(_ id: String) async { await relocate(id, .trash) }

    public func markSpam(_ id: String) async { await relocate(id, .spam) }

    public func move(_ id: String, toFolder folder: String) async { await relocate(id, .folder(folder)) }

    func relocate(_ id: String, _ move: MailMove) async {
        guard let inlet = cardInlet(id) ?? selectedInlet else { return }
        do {
            switch move {
            case .archive: try await engine.archive(inlet, messageID: id)
            case .trash: try await engine.trash(inlet, messageID: id)
            case .spam: try await engine.markSpam(inlet, messageID: id)
            case .folder(let folder): try await engine.move(inlet, messageID: id, toFolder: folder)
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
