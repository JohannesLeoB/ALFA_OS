import Hub
import Mail
import ShellCore
import SwiftUI

struct MailAccountsPane: View {
    let model: MailModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if model.accounts.isEmpty { word("mail.accounts.none").designText(\.inkTertiary) }
                ForEach(model.accounts) { account in
                    DesignRow(selected: model.selectedFolder == nil && model.selectedInlet == account.id, action: { Task { await model.selectAccount(account.id) } }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 0) {
                                word(account.title).designText()
                                if !account.account.isEmpty {
                                    Text(verbatim: account.account).designText(\.inkTertiary, size: Design.TextSize.small)
                                }
                                stateWords(account.state).designText(\.inkTertiary, size: Design.TextSize.small)
                            }
                            Spacer()
                            Text(verbatim: String(model.unread[account.id] ?? 0)).designText(\.inkTertiary)
                        }
                    }
                    if account.id == model.selectedInlet {
                        ForEach(model.sortedFolders) { folder in
                            DesignRow(selected: model.selectedFolder == folder.id, action: { Task { await model.selectFolder(folder.id) } }) {
                                Group {
                                    if folder.role.rawValue == "other" {
                                        Text(verbatim: folder.name)
                                    } else {
                                        word("mail.role." + folder.role.rawValue)
                                    }
                                }
                                .designText()
                            }
                            .padding(.leading, CGFloat(Design.Spacing.step12))
                        }
                    }
                }
            }
            .padding(CGFloat(Design.Spacing.step8))
        }
    }

    @ViewBuilder
    private func stateWords(_ state: InletState) -> some View {
        switch state {
        case .created: word("mail.state.created")
        case .signedIn: word("mail.state.signedIn")
        case .connecting: word("mail.state.loading")
        case .connected, .working: word("mail.state.connected")
        case .failed(let hint): word(hint.text == Hint.signInExpiredText ? "mail.list.signInExpired" : "mail.state.failed")
        case .keychainUnreadable: word("mail.state.keychain")
        case .orphaned: word("mail.state.orphaned")
        case .locked: word("mail.state.locked")
        }
    }
}

struct MailListPane: View {
    let model: MailModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let key = model.listState.key {
                word(key).designText(\.inkTertiary).padding(CGFloat(Design.Spacing.step12))
            }
            if case .failed(let hint) = model.listState {
                hintWords(hint).designText(\.signal).padding(CGFloat(Design.Spacing.step12))
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(model.rows) { row in
                        let unread = row.states.contains(.unread)
                        DesignRow(selected: model.selectedMessage == row.id, action: { Task { await model.open(row.id) } }) {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    Text(verbatim: row.summary.from).designText(weight: unread ? .medium : .regular)
                                    Spacer()
                                    if let date = row.summary.receivedAt {
                                        Text(date, format: .dateTime).designText(\.inkTertiary, size: Design.TextSize.small)
                                    }
                                }
                                HStack {
                                    Text(verbatim: row.summary.subject).designText(\.inkSecondary, size: Design.TextSize.small).lineLimit(1)
                                    Spacer()
                                    if unread { word(MailRowState.unread.key).designText(\.inkTertiary, size: Design.TextSize.small) }
                                }
                            }
                        }
                    }
                    if model.canLoadMore {
                        Button { Task { await model.loadMore() } } label: { word("mail.loadMore").designText(\.inkSecondary) }
                            .buttonStyle(.plain)
                            .padding(CGFloat(Design.Spacing.step12))
                    }
                }
                .padding(CGFloat(Design.Spacing.step8))
            }
        }
    }
}

struct MailReadingPane: View {
    let model: MailModel

    var body: some View {
        if model.cards.isEmpty {
            Color.clear
        } else {
            CardStackView(model: model)
        }
    }
}
