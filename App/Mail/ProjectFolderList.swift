import AppKit
import Core
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
            let hidden = files.count - Tokens.Count.projectFilesMax
            let rows = files.prefix(Tokens.Count.projectFilesMax).map { file in
                MenuEntry.row(MenuItem(id: file.id, label: Text(verbatim: file.name), meta: appearance.text("mail.menu.drive")) {
                    if file.isFolder {
                        open(inbox, appearance: appearance, draft: draft, anchor: anchor, inlet: inlet, folder: file.id, title: file.name)
                    } else {
                        Task { await inbox.attachProjectFile(draft, inlet: inlet, file: file) }
                    }
                })
            }
            let more = hidden > 0
                ? [MenuEntry.head(id: "more", label: Text(verbatim: appearance.format("mail.menu.projectMore", Format.number(hidden))))]
                : []
            present([.head(id: "head", label: Text(verbatim: title))] + rows + more, anchor: anchor)
        }
    }

    private static func present(_ entries: [MenuEntry], anchor: NSRect) {
        MenuPanel.shared.show(entries: entries, anchor: .rect(anchor), window: NSApp.keyWindow)
    }
}
