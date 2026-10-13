import Hub
import Mail
import SwiftUI

struct MailAccountsPane: View {
    let model: MailModel

    private enum Pick: Hashable {
        case account(Inlet.ID)
        case folder(String)
    }

    private var pick: Binding<Pick?> {
        Binding(
            get: { model.selectedFolder.map(Pick.folder) ?? model.selectedInlet.map(Pick.account) },
            set: { pick in
                switch pick {
                case .account(let id): Task { await model.selectAccount(id) }
                case .folder(let id): Task { await model.selectFolder(id) }
                case nil: break
                }
            })
    }

    var body: some View {
        List(selection: pick) {
            if model.accounts.isEmpty { word("mail.accounts.none") }
            ForEach(model.accounts) { account in
                HStack {
                    VStack(alignment: .leading) {
                        word(account.title)
                        if !account.account.isEmpty { Text(verbatim: account.account) }
                        stateWords(account.state)
                    }
                    Spacer()
                    Text(verbatim: String(model.unread[account.id] ?? 0))
                }
                .tag(Pick.account(account.id))
                if account.id == model.selectedInlet {
                    ForEach(model.sortedFolders) { folder in
                        Group {
                            if folder.role.rawValue == "other" {
                                Text(verbatim: folder.name)
                            } else {
                                word("mail.role." + folder.role.rawValue)
                            }
                        }
                        .tag(Pick.folder(folder.id))
                    }
                }
            }
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
        VStack(alignment: .leading) {
            if let key = model.listState.key { word(key) }
            if case .failed(let hint) = model.listState { hintWords(hint) }
            List(selection: message) {
                ForEach(model.rows) { row in
                    VStack(alignment: .leading) {
                        HStack {
                            Text(verbatim: row.summary.from)
                            Spacer()
                            if let date = row.summary.receivedAt { Text(date, format: .dateTime) }
                        }
                        HStack {
                            Text(verbatim: row.summary.subject)
                            Spacer()
                            if row.states.contains(.unread) { word(MailRowState.unread.key) }
                        }
                    }
                    .tag(row.id)
                }
                if model.canLoadMore {
                    Button { Task { await model.loadMore() } } label: { word("mail.loadMore") }
                }
            }
        }
    }

    private var message: Binding<String?> {
        Binding(
            get: { model.selectedMessage },
            set: { id in if let id { Task { await model.open(id) } } })
    }
}

struct MailReadingPane: View {
    let model: MailModel

    var body: some View {
        if let card = model.cards.first(where: { $0.id == model.selectedMessage }) {
            ScrollView {
                VStack(alignment: .leading) {
                    Text(verbatim: card.summary.subject)
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
