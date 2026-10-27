import AppKit
import Hub
import Mail
import SwiftUI
import UniformTypeIdentifiers

extension AppSession {
    func perform(_ action: Action, message id: String, undoable: Bool = false, fromMenu: Bool = false) {
        if ActionRouter(state: inbox).message(action, id, undoable: undoable, fromMenu: fromMenu) { return }
        switch action {
        case .print: Task { await MessageExport.printMail(inbox, id) }
        case .pdf: Task { await MessageExport.savePDF(inbox, id) }
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
            openMailService(SettingsSection.contacts.rawValue)
        default: break
        }
    }

    func personEntries(name: String, address: String, appearance: Appearance) -> [MenuEntry] {
        MenuLine.entries(MenuEngine.person(address: address, contact: inbox.contact(address) != nil), appearance: appearance) { action in
            self.perform(action, name: name, address: address)
        }
    }

    func openMailSettings() {
        desk.select("settings")
    }

    func openMailService(_ id: String) {
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
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        let urls = panel.urls
        let inbox = self.inbox
        Task {
            for url in urls {
                guard let data = try? await Task.detached(operation: { try Data(contentsOf: url) }).value else { continue }
                let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
                inbox.attach(id, filename: url.lastPathComponent, mimeType: mime, data: data)
            }
        }
    }
}
