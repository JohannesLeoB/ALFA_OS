import Mail
import SwiftUI

struct MailCommands: Commands {
    let session: AppSession?
    @FocusedValue(\.mailMenu) private var target

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            item(titleKey: "shell.menu.newMessage", shortcut: KeyboardShortcut("n", modifiers: .command), enabled: session != nil) { compose() }
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
        }
        CommandMenu(LocalizedStringKey("shell.menu.mailbox")) {
            item(titleKey: "shell.menu.fetchAll", shortcut: KeyboardShortcut("n", modifiers: [.command, .shift]), enabled: session != nil && session?.syncing == false) { fetch() }
            Divider()
            item(titleKey: "mail.action.archive", shortcut: KeyboardShortcut("a", modifiers: [.command, .control]), enabled: allows(.archive)) { target?.perform(.archive) }
            item(titleKey: "mail.action.spam", shortcut: KeyboardShortcut("j", modifiers: [.command, .shift]), enabled: target?.isMessage == true) { target?.perform(.spam) }
        }
        CommandMenu(LocalizedStringKey("shell.menu.message")) {
            item(titleKey: "mail.action.reply", shortcut: KeyboardShortcut("r", modifiers: .command), enabled: allows(.reply)) { target?.perform(.reply) }
            item(titleKey: "mail.action.replyAll", shortcut: KeyboardShortcut("r", modifiers: [.command, .shift]), enabled: allows(.replyAll)) { target?.perform(.replyAll) }
            item(titleKey: "mail.action.forward", shortcut: KeyboardShortcut("f", modifiers: [.command, .shift]), enabled: allows(.forward)) { target?.perform(.forward) }
            item(titleKey: "mail.action.send", shortcut: KeyboardShortcut("d", modifiers: [.command, .shift]), enabled: allows(.send)) { target?.perform(.send) }
            Divider()
            item(titleKey: target?.read == false ? "mail.action.markRead" : "mail.action.markUnread", shortcut: KeyboardShortcut("u", modifiers: [.command, .shift]),
                 enabled: target?.isMessage == true) { target?.perform(target?.read == false ? .markRead : .markUnread) }
            item(titleKey: target?.starred == true ? "mail.action.unstar" : "mail.action.star", shortcut: KeyboardShortcut("l", modifiers: [.command, .shift]),
                 enabled: target?.isMessage == true) { target?.perform(target?.starred == true ? .unstar : .star) }
        }
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
