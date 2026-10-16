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
    private func center(_ setup: any HubSetup) -> some View {
        switch host.section {
        case .integrations: SettingsInletsPane(host: host, setup: setup)
        case .appearance: SettingsAppearancePane()
        case .system: SettingsSystemPane()
        }
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
            case .leading: SettingsGroupsPane(host: host)
            case .center: center(assembly.hub.setup)
            case .trailing:
                if host.section == .integrations {
                    SettingsAddPane(host: host, offers: assembly.hub.setup.offers)
                } else {
                    Color.clear
                }
            }
        }
    }
}

struct SettingsGroupsPane: View {
    @Bindable var host: AppHost

    private var pick: Binding<SettingsSection?> {
        Binding(
            get: { host.section },
            set: { section in if let section { host.section = section } })
    }

    var body: some View {
        List(selection: pick) {
            ForEach(SettingsGroup.allCases, id: \.self) { group in
                Section {
                    ForEach(SettingsSection.allCases.filter { $0.group == group }) { section in
                        word(section.key).tag(section)
                    }
                } header: {
                    word(group.key)
                }
            }
        }
    }
}

struct SettingsAppearancePane: View {
    @AppStorage("appearance") private var choice = AppearanceChoice.system.rawValue

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(AppearanceChoice.allCases, id: \.self) { option in
                Button { choice = option.rawValue } label: {
                    HStack {
                        word(option.key)
                        if choice == option.rawValue { Image(systemName: "checkmark") }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
    }
}

struct SettingsSystemPane: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    var body: some View {
        VStack(alignment: .leading) {
            line(.version, version)
            line(.tokenDelivery, DesignStamp.delivery)
            line(.tokenDeliveredAt, DesignStamp.deliveredAt)
            line(.tokenAdoptedAt, DesignStamp.adoptedAt)
            line(.tokenState, DesignStamp.state)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
    }

    private func line(_ label: SettingsLabel, _ value: String) -> some View {
        VStack(alignment: .leading) {
            word(label.key)
            Text(verbatim: value)
        }
        .padding(.bottom)
    }
}

extension AppearanceChoice {
    var scheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
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
                word(inlet.title)
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
                word("text.settings.action.addAccount")
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
