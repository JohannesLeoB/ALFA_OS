import Core
import Design
import Hub
import Mail
import SwiftUI

@MainActor
enum ProjectFolderList {
    static func show(_ session: AppSession, appearance: Appearance, draft: UUID, anchor: AnchorBox) {
        projects(session, appearance: appearance, title: "mail.action.fromProject", anchor: anchor) { project in
            open(session, appearance: appearance, draft: draft, anchor: anchor, inlet: project.inlet, folder: project.folder.id,
                 trail: project.folder.name)
        }
    }

    static func save(_ session: AppSession, appearance: Appearance, message id: String, anchor: AnchorBox) {
        projects(session, appearance: appearance, title: "mail.saveMail.chooseProject", rootTitle: "mail.saveMail.menu", anchor: anchor) { project in
            Task { await session.inbox.mailToProjectFolder(id, project: project, render: { MessageExport.render($0, settings: session.settings) }) }
        }
    }

    static func save(_ session: AppSession, appearance: Appearance, message id: String, attachment: AttachmentEntry, anchor: AnchorBox) {
        projects(session, appearance: appearance, title: "mail.attachment.otherProject", anchor: anchor) { project in
            Task { await session.inbox.attachmentToProjectFolder(id, attachmentID: attachment.id, name: attachment.name, project: project) }
        }
    }

    private static func projects(_ session: AppSession, appearance: Appearance, title: String, rootTitle: String? = nil, anchor: AnchorBox,
                                 pick: @escaping @MainActor (ProjectFolder) -> Void) {
        guard session.hasProjectRoot else {
            noRoot(session, appearance: appearance, title: rootTitle ?? title, anchor: anchor)
            return
        }
        let head = MenuEntry.head(id: "head", label: appearance.text(title))
        guard let ticket = anchor.showMenu([head, note("mail.projectFiles.loading", appearance: appearance)]) else { return }
        Task {
            let found = await session.inbox.projectFolders()
            guard MenuPanel.shared.isCurrent(ticket) else { return }
            guard let found else {
                anchor.showMenu([head, note("mail.projectFiles.loadFailed", appearance: appearance),
                                 retry(appearance: appearance) {
                    projects(session, appearance: appearance, title: title, rootTitle: rootTitle, anchor: anchor, pick: pick)
                }])
                return
            }
            guard !found.isEmpty else {
                anchor.showMenu([head, note("mail.projectFiles.empty", appearance: appearance)])
                return
            }
            let rows = found.map { project in
                MenuEntry.row(MenuItem(id: project.id, label: Text(verbatim: project.folder.name)) { pick(project) })
            }
            anchor.showMenu([head] + rows)
        }
    }

    private static func open(_ session: AppSession, appearance: Appearance, draft: UUID, anchor: AnchorBox, inlet: String, folder: String,
                             trail: String) {
        let head = MenuEntry.head(id: "head", label: Text(verbatim: trail))
        guard let ticket = anchor.showMenu([head, note("mail.projectFiles.loading", appearance: appearance)]) else { return }
        Task {
            let listed = await session.inbox.projectFiles(inlet, folder: folder)
            guard MenuPanel.shared.isCurrent(ticket) else { return }
            guard let files = listed else {
                anchor.showMenu([head, note("mail.projectFiles.loadFailed", appearance: appearance),
                                 retry(appearance: appearance) {
                    open(session, appearance: appearance, draft: draft, anchor: anchor, inlet: inlet, folder: folder, trail: trail)
                }])
                return
            }
            guard !files.isEmpty else {
                anchor.showMenu([head, note("mail.projectFiles.empty", appearance: appearance)])
                return
            }
            let shown = Array(files.prefix(Tokens.Count.projectFilesMax))
            let counts = await session.inbox.projectCounts(inlet, folders: shown)
            guard MenuPanel.shared.isCurrent(ticket) else { return }
            let rows = shown.map { file in
                MenuEntry.row(MenuItem(id: file.id, label: Text(verbatim: file.name),
                                       meta: meta(of: file, counts: counts)) {
                    if file.isFolder {
                        open(session, appearance: appearance, draft: draft, anchor: anchor, inlet: inlet, folder: file.id,
                             trail: trail + " · " + file.name)
                    } else {
                        Task { await session.inbox.attachProjectFile(draft, inlet: inlet, file: file) }
                    }
                })
            }
            let hidden = files.count - shown.count
            let more = hidden > 0
                ? [MenuEntry.head(id: "more", label: Text(verbatim: appearance.format("mail.projectFiles.more", Format.number(hidden))))]
                : []
            anchor.showMenu([head] + rows + more)
        }
    }

    private static func meta(of file: FileEntry, counts: [String: Int]) -> Text? {
        if file.isFolder { return counts[file.id].map { Text(verbatim: Format.number($0)) } }
        guard let size = file.size, size > 0 else { return nil }
        return Text(verbatim: Format.bytes(size))
    }

    private static func noRoot(_ session: AppSession, appearance: Appearance, title: String, anchor: AnchorBox) {
        anchor.showMenu([
            .head(id: "head", label: appearance.text(title)),
            note("mail.projectFiles.noRoot", appearance: appearance),
            .row(MenuItem(id: "chooseRoot", label: appearance.text("mail.projectFiles.chooseRoot")) { session.openSettingsCard("google") }),
        ])
    }

    private static func note(_ key: String, appearance: Appearance) -> MenuEntry {
        .head(id: key, label: appearance.text(key))
    }

    private static func retry(appearance: Appearance, action: @escaping () -> Void) -> MenuEntry {
        .row(MenuItem(id: "retry", label: appearance.text("mail.projectFiles.retry"), action: action))
    }
}
