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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(SettingsGroup.allCases, id: \.self) { group in
                    word(group.key)
                        .designText(\.inkTertiary, size: Design.TextSize.small)
                        .padding(.horizontal, CGFloat(Design.Spacing.step12))
                        .padding(.top, CGFloat(Design.Spacing.step12))
                        .padding(.bottom, CGFloat(Design.Spacing.step4))
                    ForEach(SettingsSection.allCases.filter { $0.group == group }) { section in
                        DesignRow(selected: host.section == section, action: { host.section = section }) {
                            word(section.key).designText()
                        }
                    }
                }
            }
            .padding(CGFloat(Design.Spacing.step8))
        }
    }
}

struct SettingsAppearancePane: View {
    @AppStorage("appearance") private var choice = AppearanceChoice.system.rawValue

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(AppearanceChoice.allCases, id: \.self) { option in
                    DesignRow(selected: choice == option.rawValue, action: { choice = option.rawValue }) {
                        HStack {
                            word(option.key).designText()
                            Spacer()
                            if choice == option.rawValue { Image(systemName: "checkmark").designText(\.inkSecondary) }
                        }
                    }
                }
            }
            .padding(CGFloat(Design.Spacing.step8))
        }
    }
}

struct SettingsSystemPane: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CGFloat(Design.Spacing.step12)) {
                line(.version, version)
                line(.tokenDelivery, DesignStamp.delivery)
                line(.tokenDeliveredAt, DesignStamp.deliveredAt)
                line(.tokenAdoptedAt, DesignStamp.adoptedAt)
                line(.tokenState, DesignStamp.state)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(CGFloat(Design.Spacing.step12))
        }
    }

    private func line(_ label: SettingsLabel, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: CGFloat(Design.Spacing.step4)) {
            word(label.key).designText(\.inkTertiary, size: Design.TextSize.small)
            Text(verbatim: value).designText()
        }
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
    @Environment(\.design) private var design

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CGFloat(Design.Spacing.step8)) {
                if setup.inlets.isEmpty { word("settings.inlets.none").designText(\.inkTertiary) }
                ForEach(setup.inlets) { inlet in row(inlet) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(CGFloat(Design.Spacing.step8))
        }
    }

    private func remove(_ id: Inlet.ID) {
        if removal.press(id) { Task { await host.remove(id) } }
    }

    private func tone(_ state: InletState) -> KeyPath<DesignColors, RGB> {
        switch state {
        case .connected, .working: \.ink
        case .failed, .keychainUnreadable, .orphaned: \.signal
        default: \.mark
        }
    }

    private func action(_ key: String, tone: KeyPath<DesignColors, RGB> = \.ink, _ run: @escaping () -> Void) -> some View {
        Button(action: run) { word(key).designText(tone, size: Design.TextSize.small, weight: .medium) }
            .buttonStyle(.plain)
    }

    private func row(_ inlet: Inlet) -> some View {
        VStack(alignment: .leading, spacing: CGFloat(Design.Spacing.step4)) {
            HStack(spacing: CGFloat(Design.Spacing.step8)) {
                DesignDot(tone: tone(inlet.state))
                word(inlet.title).designText(weight: .medium)
                Spacer()
            }
            if !inlet.account.isEmpty {
                Text(verbatim: inlet.account).designText(\.inkSecondary, size: Design.TextSize.small)
            }
            word(inlet.state.key).designText(\.inkTertiary, size: Design.TextSize.small)
            if let date = inlet.state.probed {
                Text(date, format: .dateTime).designText(\.inkTertiary, size: Design.TextSize.small)
            }
            if let hint = inlet.state.hint { hintWords(hint).designText(\.signal, size: Design.TextSize.small) }
            HStack(spacing: CGFloat(Design.Spacing.step12)) {
                action("text.settings.action.check") { Task { await host.probe(inlet.id) } }
                if inlet.state.canRenew {
                    action("text.settings.action.signInAgain") { Task { await host.renew(inlet.id) } }
                }
                if removal.armed == inlet.id {
                    action("text.settings.action.removeConfirm", tone: \.signal) { remove(inlet.id) }
                    action("text.common.cancel") { removal.cancel() }
                } else {
                    action("text.settings.action.remove", tone: \.signal) { remove(inlet.id) }
                }
            }
            .padding(.top, CGFloat(Design.Spacing.step4))
        }
        .padding(CGFloat(Design.Spacing.step12))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CGFloat(Design.Radius.row)).fill(design.color(\.well)))
    }
}

struct SettingsAddPane: View {
    @Bindable var host: AppHost
    let offers: [Offer]
    @Environment(\.design) private var design

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                word("text.settings.action.addAccount")
                    .designText(\.inkTertiary, size: Design.TextSize.small)
                    .padding(.horizontal, CGFloat(Design.Spacing.step12))
                    .padding(.vertical, CGFloat(Design.Spacing.step8))
                if let offer = host.form {
                    form(offer)
                } else {
                    ForEach(offers) { offer in
                        DesignRow(selected: false, action: { Task { await host.choose(offer) } }) {
                            word(offer.title).designText()
                        }
                    }
                }
                if host.busy { word("mail.state.loading").designText(\.inkTertiary).padding(CGFloat(Design.Spacing.step12)) }
                if let failure = host.failure {
                    hintWords(failure).designText(\.signal, size: Design.TextSize.small).padding(CGFloat(Design.Spacing.step12))
                }
                if host.form != nil {
                    DesignRow(selected: false, action: { host.close() }) { word("text.common.cancel").designText(\.inkSecondary) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(CGFloat(Design.Spacing.step8))
        }
    }

    @ViewBuilder
    private func form(_ offer: Offer) -> some View {
        let fields: [Field] = switch offer.way {
        case .form(let fields), .key(let fields): fields
        case .signIn: []
        }
        ForEach(fields) { field in
            VStack(alignment: .leading, spacing: CGFloat(Design.Spacing.step4)) {
                word(field.title).designText(\.inkTertiary, size: Design.TextSize.small)
                Group {
                    if field.secret {
                        SecureField(text: binding(field.id)) { EmptyView() }
                    } else {
                        TextField(text: binding(field.id)) { EmptyView() }
                    }
                }
                .textFieldStyle(.plain)
                .designText()
                .padding(.horizontal, CGFloat(Design.Spacing.step8))
                .frame(height: CGFloat(Design.Size.rowHeight))
                .background(RoundedRectangle(cornerRadius: CGFloat(Design.Radius.field)).fill(design.color(\.well)))
            }
            .padding(.horizontal, CGFloat(Design.Spacing.step12))
            .padding(.bottom, CGFloat(Design.Spacing.step8))
        }
        DesignRow(selected: false, action: { Task { await host.add(offer, input: .fields(host.values)) } }) {
            word("settings.signin").designText(weight: .medium)
        }
    }

    private func binding(_ id: String) -> Binding<String> {
        Binding(get: { host.values[id] ?? "" }, set: { host.values[id] = $0 })
    }
}
