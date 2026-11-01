import AppKit
import Core
import Design
import Google
import Hub
import Mail
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

extension AppSession {
    func perform(_ action: Action, message id: String, undoable: Bool = true, fromMenu: Bool = false) {
        if inbox.perform(action, message: id, undoable: undoable, fromMenu: fromMenu) { return }
        switch action {
        case .print: Task { await MessageExport.printMail(inbox, id, settings: settings) }
        case .pdf: Task { await MessageExport.savePDF(inbox, id, settings: settings) }
        default: break
        }
    }

    func perform(_ action: Action, name: String, address: String) {
        if inbox.perform(action, name: name, address: address) { return }
        switch action {
        case .copyAddress:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(address, forType: .string)
            inbox.announce(.addressCopied)
        case .editContact:
            guard let contact = inbox.contact(address) else { return }
            inbox.contacts.editing = contact.id
            openSettingsCard(SettingsSection.contacts.rawValue)
        default: break
        }
    }

    func personEntries(name: String, address: String, appearance: Appearance) -> [MenuEntry] {
        MenuLine.entries(MenuEngine.person(address: address, contact: inbox.contact(address) != nil), appearance: appearance) { action in
            self.perform(action, name: name, address: address)
        }
    }

    func switchMailbox(_ id: Inlet.ID, appearance: Appearance) {
        guard id != inbox.selectedInlet, !mailboxSwitching else { return }
        let inbox = self.inbox
        guard !appearance.still else {
            Task { await inbox.selectAccount(id) }
            return
        }
        mailboxSwitching = true
        Task {
            try? await Task.sleep(for: .seconds(Tokens.Duration.switchIn + Tokens.Duration.glassDelay))
            let swapped = inbox.swapAccount(id)
            mailboxSwitching = false
            if swapped { await inbox.loadSelection() }
        }
    }

    func openMailCard(of account: Inlet?) {
        openSettingsCard(account.flatMap { assembly.catalog.info(forProvider: $0.provider)?.id } ?? Self.accountsCard)
    }

    private static let accountsCard = "mailaccounts"

    var hasProjectRoot: Bool {
        DriveRootStore(settings: assembly.settingStore).current() != nil
            || !DriveConfigStore.load(in: assembly.directory).projectsRoot.isEmpty
    }

    func openSettingsCard(_ id: String) {
        settings.group = .connections
        settings.open(id)
        desk.select("settings")
    }
}

extension AppSession {
    func help(_ action: Action, appearance: Appearance) -> String {
        if action == .overview { return appearance.format("mail.overview.tip", String(inbox.stackCount)) }
        return appearance.string(action.key)
    }

    func attachFiles(to id: UUID) {
        let panel = NSOpenPanel()
        panel.appearance = ForeignContent.panel
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        attach(urls: panel.urls, to: id)
    }

    func attach(urls: [URL], to id: UUID) {
        let inbox = self.inbox
        Task {
            for url in urls {
                guard let data = try? await Task.detached(operation: { try Data(contentsOf: url) }).value else {
                    inbox.announce(.attachmentFailed)
                    continue
                }
                let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
                inbox.attach(id, filename: url.lastPathComponent, mimeType: mime, data: data)
            }
        }
    }
}

extension Action {
    var shortcut: KeyboardShortcut? {
        switch self {
        case .reply: KeyboardShortcut("r", modifiers: .command)
        case .replyAll: KeyboardShortcut("r", modifiers: [.command, .shift])
        case .forward: KeyboardShortcut("f", modifiers: [.command, .shift])
        case .saveDraft: KeyboardShortcut("s", modifiers: .command)
        case .print: KeyboardShortcut("p", modifiers: .command)
        default: nil
        }
    }
}

extension MenuLine {
    @MainActor
    static func entries(_ lines: [MenuLine], appearance: Appearance, warns: Bool = true, run: @escaping (Action) -> Void) -> [MenuEntry] {
        lines.enumerated().map { index, line in
            let id = String(index)
            switch line {
            case .separator: return .separator(id: id)
            case .head(let text): return .head(id: id, label: Text(verbatim: text))
            case .item(let action, let checked):
                return .row(MenuItem(id: id, label: appearance.text(action.key), check: checked ? appearance.text("mail.menu.check") : nil,
                                     danger: warns && action.danger) { run(action) })
            }
        }
    }
}

@MainActor
enum MoveFolderList {
    static func entries(_ inbox: InboxState, appearance: Appearance, message id: String) -> [MenuEntry] {
        let rows = inbox.moveTargets(id).map { folder in
            MenuEntry.row(MenuItem(id: folder.id, label: Text(verbatim: FolderTitle.text(inbox.folderName(folder.id)) { appearance.string($0) })) {
                inbox.startMove(id, to: folder.id)
            })
        }
        return [.head(id: "head", label: appearance.text("mail.action.move"))] + rows
    }
}

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

@MainActor
enum MessageExport {
    static func render(_ message: OpenMessage, settings: SettingsState) -> Data? {
        let info = NSPrintInfo.shared
        guard let template = settings.currentTemplateText,
              let html = MessagePDF.html(template: template, message: message).data(using: .utf8),
              let styled = try? NSAttributedString(data: html, options: [.documentType: NSAttributedString.DocumentType.html,
                                                                         .characterEncoding: String.Encoding.utf8.rawValue],
                                                   documentAttributes: nil) else {
            return MessagePDF.render(message, page: info.paperSize, margin: info.leftMargin)
        }
        return MessagePDF.render(styled, page: info.paperSize, margin: info.leftMargin)
    }

    static func printMail(_ inbox: InboxState, _ id: String, settings: SettingsState) async {
        guard let document = await inbox.mailDocument(id, render: { render($0, settings: settings) }) else { return }
        if !printPDF(document.data, name: document.name, scaling: .pageScaleNone) { inbox.documentFailed(id) }
    }

    static func printDraft(_ inbox: InboxState, _ id: UUID, settings: SettingsState) {
        guard let document = inbox.draftDocument(id, render: { render($0, settings: settings) }) else { return }
        if !printPDF(document.data, name: document.name, scaling: .pageScaleNone) { inbox.announce(.pdfFailed) }
    }

    @discardableResult
    static func printPDF(_ data: Data, name: String, scaling: PDFPrintScalingMode) -> Bool {
        guard let pdf = PDFDocument(data: data),
              let operation = pdf.printOperation(for: NSPrintInfo.shared, scalingMode: scaling, autoRotate: false) else { return false }
        operation.jobTitle = name
        if let window = NSApp.keyWindow {
            operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        } else {
            operation.run()
        }
        return true
    }

    static func savePDF(_ inbox: InboxState, _ id: String, settings: SettingsState) async {
        guard let document = await inbox.mailDocument(id, render: { render($0, settings: settings) }) else { return }
        let panel = NSSavePanel()
        panel.appearance = ForeignContent.panel
        panel.allowedContentTypes = [.pdf]
        panel.isExtensionHidden = false
        panel.canSelectHiddenExtension = true
        panel.nameFieldStringValue = document.name
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try document.data.write(to: url.pathExtension.isEmpty ? url.appendingPathExtension("pdf") : url)
        } catch {
            inbox.documentFailed(id)
            return
        }
        inbox.announce(.pdfSaved)
    }
}

@MainActor
enum SourceWindow {
    private static var open: [NSWindow] = []

    static func show(_ inbox: InboxState, message id: String, appearance: Appearance) {
        let title = inbox.card(id)?.summary.subject ?? ""
        Task {
            guard let source = await inbox.original(id) else { return }
            open.removeAll { !$0.isVisible }
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: Tokens.Size.previewMinWidth, height: Tokens.Size.previewMinHeight),
                                  styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.title = title
            window.contentView = NSHostingView(rootView: SourceText(source: source).environment(\.appearance, appearance))
            window.center()
            window.makeKeyAndOrderFront(nil)
            open.append(window)
        }
    }
}

private struct SourceText: View {
    @Environment(\.appearance) private var appearance
    let source: String

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            Text(verbatim: source)
                .font(.system(size: CGFloat(Tokens.TextSize.small), design: .monospaced))
                .foregroundStyle(appearance.color(\.ink))
                .textSelection(.enabled)
                .fixedSize()
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(CGFloat(Tokens.Spacing.step16))
        }
        .background(appearance.color(\.lane))
    }
}
