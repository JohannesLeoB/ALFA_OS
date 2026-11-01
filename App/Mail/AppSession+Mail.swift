import AppKit
import Design
import Google
import Hub
import Mail
import SwiftUI
import UniformTypeIdentifiers

extension AppSession {
    func perform(_ action: Action, message id: String, undoable: Bool = true, fromMenu: Bool = false) {
        if ActionRouter(state: inbox).message(action, id, undoable: undoable, fromMenu: fromMenu) { return }
        switch action {
        case .print: Task { await MessageExport.printMail(inbox, id, settings: settings) }
        case .pdf: Task { await MessageExport.savePDF(inbox, id, settings: settings) }
        default: break
        }
    }

    func perform(_ action: Action, name: String, address: String) {
        if ActionRouter(state: inbox).person(action, name: name, address: address) { return }
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
