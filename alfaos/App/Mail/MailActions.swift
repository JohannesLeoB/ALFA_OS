import AppKit
import Mail
import SwiftUI

@MainActor
struct MailDo {
    let model: MailModel

    func message(_ action: MailAction, _ id: String, undoable: Bool = false, fromMenu: Bool = false) {
        switch action {
        case .reply: Task { _ = await model.reply(to: id) }
        case .replyAll: Task { _ = await model.reply(to: id, all: true) }
        case .forward: Task { _ = await model.forward(id) }
        case .archive: Task { await model.archive(id, undoable: undoable) }
        case .trash: Task { await model.trash(id, fromMenu: fromMenu) }
        case .markRead: Task { await model.setRead(id, true) }
        case .markUnread: Task { await model.setRead(id, false) }
        case .star: Task { await model.setStarred(id, true) }
        case .unstar: Task { await model.setStarred(id, false) }
        case .spam: Task { await model.markSpam(id) }
        case .print: model.print(id)
        case .pdf: model.exportPDF(id)
        case .openDraft: Task { _ = await model.editDraft(id) }
        case .loadImages: model.allowRemoteImages(id)
        case .purge: Task { await model.purge(id) }
        default:
            break
        }
    }

    func person(_ action: MailAction, name: String, address: String, message id: String) {
        switch action {
        case .copyAddress:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(address, forType: .string)
            model.announce(.addressCopied)
        case .writeMail:
            let entry = name.isEmpty ? address : "\"" + name + "\" <" + address + ">"
            _ = model.compose(to: entry)
        case .saveContact: Task { await model.contactFromSignature(id) }
        default: break
        }
    }

    func attachment(_ action: MailAction, message id: String, attachment: MailAttachmentRow) {
        switch action {
        case .otherProject: model.attachmentToProjectFolder(id, attachmentID: attachment.id)
        case .saveAs:
            Task {
                guard let data = await model.attachmentData(id, attachmentID: attachment.id) else { return }
                let panel = NSSavePanel()
                panel.nameFieldStringValue = attachment.name
                guard panel.runModal() == .OK, let url = panel.url else { return }
                try? data.write(to: url)
            }
        default: break
        }
    }
}
