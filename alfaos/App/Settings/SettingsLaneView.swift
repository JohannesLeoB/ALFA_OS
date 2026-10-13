import Hub
import Mail
import ShellCore
import SwiftUI

struct SettingsLaneView: View {
    let lane: Lane
    @Environment(\.hostLive) private var live
    @Environment(\.appHost) private var host

    var body: some View {
        if live, let host {
            SettingsLaneContent(host: host, lane: lane)
        } else {
            Color.clear.frame(maxHeight: .infinity)
        }
    }
}

private struct SettingsLaneContent: View {
    @Bindable var host: AppHost
    let lane: Lane

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onAppear { host.prepare() }
    }

    @ViewBuilder
    private var content: some View {
        switch host.phase {
        case .idle:
            word("mail.state.loading")
        case .failed(let description):
            VStack(alignment: .leading) {
                word("mail.state.failed")
                Text(verbatim: description)
            }
        case .ready(let assembly):
            switch lane {
            case .leading: SettingsGroupsPane()
            case .center: SettingsInletsPane(host: host, setup: assembly.hub.setup)
            case .trailing: SettingsAddPane(host: host, offers: assembly.hub.setup.offers)
            }
        }
    }
}

struct SettingsGroupsPane: View {
    var body: some View {
        VStack(alignment: .leading) {
            word("text.settings.row.mail.accounts").fontWeight(.bold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}

struct SettingsInletsPane: View {
    let host: AppHost
    let setup: any HubSetup
    @State private var removal = TwoStep<Inlet.ID>()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                if setup.inlets.isEmpty { word("settings.inlets.none") }
                ForEach(setup.inlets) { inlet in row(inlet) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }

    private func remove(_ id: Inlet.ID) {
        if removal.press(id) { Task { await host.remove(id) } }
    }

    private func row(_ inlet: Inlet) -> some View {
        VStack(alignment: .leading) {
            HStack {
                word(inlet.title).fontWeight(.bold)
                if !inlet.account.isEmpty { Text(verbatim: inlet.account) }
            }
            word(inlet.state.key)
            if let date = inlet.state.probed { Text(date, format: .dateTime) }
            if let hint = inlet.state.hint { hintWords(hint) }
            HStack {
                Button { Task { await host.probe(inlet.id) } } label: { word("text.settings.action.check") }
                if inlet.state.canRenew {
                    Button { Task { await host.renew(inlet.id) } } label: { word("text.settings.action.signInAgain") }
                }
                if removal.armed == inlet.id {
                    Button { remove(inlet.id) } label: { word("text.settings.action.removeConfirm") }
                    Button { removal.cancel() } label: { word("text.common.cancel") }
                } else {
                    Button { remove(inlet.id) } label: { word("text.settings.action.remove") }
                }
            }
        }
        .padding(.bottom)
    }
}

struct SettingsAddPane: View {
    @Bindable var host: AppHost
    let offers: [Offer]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                word("text.settings.action.addAccount").fontWeight(.bold)
                if let offer = host.form {
                    form(offer)
                } else {
                    ForEach(offers) { offer in
                        Button { Task { await host.choose(offer) } } label: { word(offer.title) }
                    }
                }
                if host.busy { word("mail.state.loading") }
                if let failure = host.failure { hintWords(failure) }
                if host.form != nil {
                    Button { host.close() } label: { word("text.common.cancel") }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }

    @ViewBuilder
    private func form(_ offer: Offer) -> some View {
        let fields: [Field] = switch offer.way {
        case .form(let fields), .key(let fields): fields
        case .signIn: []
        }
        ForEach(fields) { field in
            VStack(alignment: .leading) {
                word(field.title)
                if field.secret {
                    SecureField(text: binding(field.id)) { EmptyView() }
                } else {
                    TextField(text: binding(field.id)) { EmptyView() }
                }
            }
        }
        Button { Task { await host.add(offer, input: .fields(host.values)) } } label: { word("settings.signin") }
    }

    private func binding(_ id: String) -> Binding<String> {
        Binding(get: { host.values[id] ?? "" }, set: { host.values[id] = $0 })
    }
}
