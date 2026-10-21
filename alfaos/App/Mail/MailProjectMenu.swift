import AppKit
import Hub
import Mail
import ShellCore
import SwiftUI

@MainActor
enum MailProjectMenu {
    static func show(_ model: MailModel, draft: UUID, anchor: NSRect) {
        Task {
            let projects = await model.projectFolders(for: draft)
            guard !projects.isEmpty else { return }
            let rows = projects.map { project in
                MenuEntry.row(MenuItem(id: project.id, label: Text(verbatim: project.name), meta: word("mail.menu.drive")) {
                    open(model, draft: draft, anchor: anchor, inlet: project.inlet, folder: project.folderID, title: project.name)
                })
            }
            present([.head(id: "head", label: word("mail.action.fromProject"))] + rows, anchor: anchor)
        }
    }

    static func save(_ model: MailModel, message id: String, anchor: NSRect) {
        let info = NSPrintInfo.shared
        Task {
            let projects = await model.projectFolders(forMessage: id)
            guard !projects.isEmpty else { return }
            let rows = projects.map { project in
                MenuEntry.row(MenuItem(id: project.id, label: Text(verbatim: project.name), meta: word("mail.menu.drive")) {
                    Task {
                        await model.mailToProjectFolder(id, project: project) { MailPDF.render($0, page: info.paperSize, margin: info.leftMargin) }
                    }
                })
            }
            present(rows, anchor: anchor)
        }
    }

    private static func open(_ model: MailModel, draft: UUID, anchor: NSRect, inlet: String, folder: String, title: String) {
        Task {
            let files = await model.projectFiles(inlet, folder: folder, for: draft)
            guard !files.isEmpty else { return }
            let rows = files.map { file in
                MenuEntry.row(MenuItem(id: file.id, label: Text(verbatim: file.name), meta: word("mail.menu.drive")) {
                    if file.isFolder {
                        open(model, draft: draft, anchor: anchor, inlet: inlet, folder: file.id, title: file.name)
                    } else {
                        Task { await model.attachProjectFile(draft, inlet: inlet, file: file) }
                    }
                })
            }
            present([.head(id: "head", label: Text(verbatim: title))] + rows, anchor: anchor)
        }
    }

    private static func present(_ entries: [MenuEntry], anchor: NSRect) {
        MenuPanel.shared.show(entries: entries, width: Design.Size.menuWidthAttach, anchor: .rect(anchor), window: NSApp.keyWindow)
    }
}
