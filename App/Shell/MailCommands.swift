import AppKit
import Mail
import SwiftUI
import WebKit

struct MailCommands: Commands {
    let session: AppSession?
    @FocusedValue(\.mailMenu) private var target

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            item(titleKey: "shell.menu.newMessage", shortcut: KeyboardShortcut("n", modifiers: .command), enabled: session != nil) { compose() }
        }
        CommandGroup(replacing: .undoRedo) {
            item(titleKey: "mail.toast.undo", shortcut: KeyboardShortcut("z", modifiers: .command), enabled: session != nil) { undo() }
            item(titleKey: "shell.menu.redo", shortcut: KeyboardShortcut("z", modifiers: [.command, .shift]), enabled: session != nil) { redo() }
        }
        CommandGroup(replacing: .saveItem) {
            item(titleKey: "mail.action.saveDraft", shortcut: KeyboardShortcut("s", modifiers: .command), enabled: allows(.saveDraft)) { target?.perform(.saveDraft) }
        }
        CommandGroup(replacing: .printItem) {
            item(titleKey: "mail.action.print", shortcut: KeyboardShortcut("p", modifiers: .command), enabled: allows(.print)) { target?.perform(.print) }
        }
        CommandGroup(after: .textEditing) {
            item(titleKey: "mail.search.open", shortcut: KeyboardShortcut("f", modifiers: [.command, .option]), enabled: target != nil) { search() }
        }
        CommandGroup(before: .toolbar) {
            let fanned = session?.inbox.overview.open == true
            item(titleKey: fanned ? "mail.action.backToStack" : "mail.action.overview", shortcut: nil,
                 enabled: allows(fanned ? .backToStack : .overview)) { target?.perform(fanned ? .backToStack : .overview) }
            item(titleKey: "mail.action.foldColumn", shortcut: nil, enabled: allows(.foldColumn)) { target?.perform(.foldColumn) }
            Toggle(isOn: unreadOnly) { Text(LocalizedStringKey("mail.filter.unread")) }
                .keyboardShortcut("l", modifiers: .command)
                .disabled(session == nil)
        }
        CommandMenu(LocalizedStringKey("shell.menu.mailbox")) {
            item(titleKey: "shell.menu.fetchAll", shortcut: KeyboardShortcut("n", modifiers: [.command, .shift]), enabled: session != nil && session?.syncing == false) { fetch() }
            Divider()
            item(titleKey: "mail.action.archive", shortcut: KeyboardShortcut("a", modifiers: [.command, .control]), enabled: allows(.archive)) { target?.perform(.archive) }
            item(titleKey: "mail.action.spam", shortcut: KeyboardShortcut("j", modifiers: [.command, .shift]), enabled: target?.isMessage == true && session?.inbox.folderActions != false) { target?.perform(.spam) }
        }
        CommandMenu(LocalizedStringKey("shell.menu.message")) {
            item(titleKey: "mail.action.reply", shortcut: KeyboardShortcut("r", modifiers: .command), enabled: allows(.reply)) { target?.perform(.reply) }
            item(titleKey: "mail.action.replyAll", shortcut: KeyboardShortcut("r", modifiers: [.command, .shift]), enabled: allows(.replyAll)) { target?.perform(.replyAll) }
            item(titleKey: "mail.action.forward", shortcut: KeyboardShortcut("f", modifiers: [.command, .shift]), enabled: allows(.forward)) { target?.perform(.forward) }
            item(titleKey: "mail.action.send", shortcut: KeyboardShortcut("d", modifiers: [.command, .shift]), enabled: allows(.send)) { target?.perform(.send) }
            item(titleKey: "mail.action.attachFile", shortcut: KeyboardShortcut("a", modifiers: [.command, .shift]), enabled: allows(.attachFile)) {
                target?.perform(.attachFile)
            }
            Divider()
            item(titleKey: target?.read == false ? "mail.action.markRead" : "mail.action.markUnread", shortcut: KeyboardShortcut("u", modifiers: [.command, .shift]),
                 enabled: target?.isMessage == true) { target?.perform(target?.read == false ? .markRead : .markUnread) }
            item(titleKey: target?.starred == true ? "mail.action.unstar" : "mail.action.star", shortcut: KeyboardShortcut("l", modifiers: [.command, .shift]),
                 enabled: target?.isMessage == true) { target?.perform(target?.starred == true ? .unstar : .star) }
        }
    }

    private var unreadOnly: Binding<Bool> {
        Binding(get: { session?.inbox.filter == .unread }, set: { session?.inbox.setFilter($0 ? .unread : .all) })
    }

    private func allows(_ action: Action) -> Bool {
        target?.allows(action) == true
    }

    private func item(titleKey: String, shortcut: KeyboardShortcut?, enabled: Bool,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(LocalizedStringKey(titleKey)) }
            .keyboardShortcut(shortcut)
            .disabled(!enabled)
    }

    private var editing: Bool {
        guard let responder = NSApp.keyWindow?.firstResponder else { return false }
        if responder is NSText { return true }
        var view = responder as? NSView
        while let current = view {
            if current is WKWebView { return true }
            view = current.superview
        }
        return false
    }

    private func undo() {
        guard let inbox = session?.inbox, !editing, inbox.toast?.undoable == true, inbox.toast?.kind.failed == false else {
            NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
            return
        }
        Task { await inbox.undoToast() }
    }

    private func redo() {
        NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
    }

    private func compose() {
        guard let session else { return }
        _ = session.inbox.compose()
        session.desk.select("mail")
    }

    private func search() {
        guard let session else { return }
        Task { await session.inbox.setSearching(true) }
    }

    private func fetch() {
        guard let session else { return }
        Task { await session.sync() }
    }
}
