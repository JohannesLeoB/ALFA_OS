import Hub
import Mail
import SwiftUI

struct MailAccountsPane: View {
    let model: MailModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                if model.accounts.isEmpty { word("mail.accounts.none") }
                ForEach(model.accounts) { account in
                    Button { Task { await model.selectAccount(account.id) } } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                word(account.title)
                                if !account.account.isEmpty { Text(verbatim: account.account) }
                                stateWords(account.state)
                            }
                            Spacer()
                            Text(verbatim: String(model.unread[account.id] ?? 0))
                        }
                        .fontWeight(account.id == model.selectedInlet ? .bold : .regular)
                    }
                    .buttonStyle(.plain)
                }
                ForEach(model.sortedFolders) { folder in
                    Button { Task { await model.selectFolder(folder.id) } } label: {
                        if folder.role.rawValue == "other" {
                            Text(verbatim: folder.name)
                        } else {
                            word("mail.role." + folder.role.rawValue)
                        }
                    }
                    .buttonStyle(.plain)
                    .fontWeight(folder.id == model.selectedFolder ? .bold : .regular)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }

    @ViewBuilder
    private func stateWords(_ state: InletState) -> some View {
        switch state {
        case .created: word("mail.state.created")
        case .signedIn: word("mail.state.signedIn")
        case .connecting: word("mail.state.loading")
        case .connected, .working: word("mail.state.connected")
        case .failed(let hint): word(hint.text == MailKey.signInExpiredHint ? "mail.list.signInExpired" : "mail.state.failed")
        case .keychainUnreadable: word("mail.state.keychain")
        case .orphaned: word("mail.state.orphaned")
        case .locked: word("mail.state.locked")
        }
    }
}

struct MailListPane: View {
    let model: MailModel

    var body: some View {
        VStack(alignment: .leading) {
            if let key = model.listState.key { word(key) }
            if case .failed(let hint) = model.listState { hintWords(hint) }
            List(model.rows) { row in
                Button { Task { await model.open(row.id) } } label: {
                    VStack(alignment: .leading) {
                        HStack {
                            Text(verbatim: row.summary.from)
                            Spacer()
                            if let date = row.summary.receivedAt { Text(date, format: .dateTime) }
                        }
                        HStack {
                            Text(verbatim: row.summary.subject)
                            Spacer()
                            if row.unread { word(row.states.first?.key ?? "mail.row.unread") }
                        }
                    }
                    .fontWeight(row.unread ? .bold : .regular)
                    .underline(row.selected)
                }
                .buttonStyle(.plain)
            }
            if model.canLoadMore {
                Button { Task { await model.loadMore() } } label: { word("mail.loadMore") }
            }
        }
    }
}

struct MailReadingPane: View {
    let model: MailModel

    var body: some View {
        if let card = model.cards.first(where: { $0.id == model.selectedMessage }) {
            ScrollView {
                VStack(alignment: .leading) {
                    Text(verbatim: card.summary.subject).font(.headline)
                    Text(verbatim: card.summary.from)
                    if let hint = model.actionFailure(for: card.id) { hintWords(hint) }
                    content(card.content)
                }
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private func content(_ content: MailCardContent) -> some View {
        switch content {
        case .text(let text): Text(verbatim: text)
        case .html(let html, _): Text(verbatim: MailText.plain(html))
        case .bodyLoading, .conversation, .draftNotice: word(content.key ?? "mail.card.bodyLoading")
        }
    }
}
