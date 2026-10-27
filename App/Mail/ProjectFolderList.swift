import AppKit
import Design
import Hub
import Mail
import SwiftUI

@MainActor
enum ProjectFolderList {
    static func show(_ inbox: InboxState, appearance: Appearance, draft: UUID, anchor: NSRect) {
        Task {
            let projects = await inbox.projectFolders(for: draft)
            guard !projects.isEmpty else { return }
            let rows = projects.map { project in
                MenuEntry.row(MenuItem(id: project.id, label: Text(verbatim: project.folder.name), meta: appearance.text("mail.menu.drive")) {
                    open(inbox, appearance: appearance, draft: draft, anchor: anchor, inlet: project.inlet, folder: project.folder.id,
                         title: project.folder.name)
                })
            }
            present([.head(id: "head", label: appearance.text("mail.action.fromProject"))] + rows, anchor: anchor)
        }
    }

    static func save(_ inbox: InboxState, appearance: Appearance, message id: String, anchor: NSRect) {
        Task {
            let projects = await inbox.projectFolders(forMessage: id)
            guard !projects.isEmpty else { return }
            let rows = projects.map { project in
                MenuEntry.row(MenuItem(id: project.id, label: Text(verbatim: project.folder.name), meta: appearance.text("mail.menu.drive")) {
                    Task { await inbox.mailToProjectFolder(id, project: project, render: MessageExport.render) }
                })
            }
            present(rows, anchor: anchor)
        }
    }

    private static func open(_ inbox: InboxState, appearance: Appearance, draft: UUID, anchor: NSRect, inlet: String, folder: String,
                             title: String) {
        Task {
            let files = await inbox.projectFiles(inlet, folder: folder)
            guard !files.isEmpty else { return }
            let rows = files.map { file in
                MenuEntry.row(MenuItem(id: file.id, label: Text(verbatim: file.name), meta: appearance.text("mail.menu.drive")) {
                    if file.isFolder {
                        open(inbox, appearance: appearance, draft: draft, anchor: anchor, inlet: inlet, folder: file.id, title: file.name)
                    } else {
                        Task { await inbox.attachProjectFile(draft, inlet: inlet, file: file) }
                    }
                })
            }
            present([.head(id: "head", label: Text(verbatim: title))] + rows, anchor: anchor)
        }
    }

    private static func present(_ entries: [MenuEntry], anchor: NSRect) {
        MenuPanel.shared.show(entries: entries, width: Tokens.Size.menuWidthAttach, anchor: .rect(anchor), window: NSApp.keyWindow)
    }
}
