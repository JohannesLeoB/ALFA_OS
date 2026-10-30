import Assistant
import Hub
import SwiftUI

struct SettingsDetail: View {
    let context: SettingsContext
    let id: String
    var disconnecting = false
    var endDisconnect: () -> Void = {}

    var body: some View {
        if let info = context.catalog.info(id) {
            IntegrationCard(context: context, info: info, disconnecting: disconnecting, endDisconnect: endDisconnect)
        } else if let section = SettingsSection(rawValue: id) {
            switch section {
            case .identity: IdentityCard(context: context)
            case .appearance: AppearanceCard(state: context.state)
            case .companyData: CompanyCard(state: context.state)
            case .folders: FoldersCard()
            case .templates: TemplatesCard()
            case .integrations: EmptyView()
            case .keyInventory: KeyCard(context: context)
            case .contacts: ContactCard(context: context)
            case .privacy: PrivacyCard(state: context.state, privacy: context.privacy, conversation: context.conversation)
            case .system: SystemCard(state: context.state)
            case .imprint: ImprintCard(state: context.state)
            }
        }
    }
}

struct TemplatesCard: View {
    @Environment(\.appearance) private var appearance

    var body: some View {
        BlockNote(text: appearance.text("settings.templates.none"))
    }
}

struct CompanyCard: View {
    @Environment(\.appearance) private var appearance
    let state: SettingsState

    var body: some View {
        VStack(spacing: 0) {
            ForEach(CompanyEntry.allCases, id: \.self) { entry in
                SettingsRow(label: appearance.text(entry.key)) {
                    ValueField(
                        text: Binding(get: { state.company[entry.rawValue] ?? "" }, set: { state.setCompany(entry, $0) }),
                        labelKey: entry.key, prompt: appearance.text(entry.promptKey))
                }
            }
        }
    }
}

struct FoldersCard: View {
    @Environment(\.appearance) private var appearance

    var body: some View {
        VStack(spacing: 0) {
            ForEach(["settings.folders.projects", "settings.folders.data"], id: \.self) { key in
                SettingsRow(label: appearance.text(key)) {
                    SettingsValue(text: appearance.text(SettingsKeys.valueEmpty), tone: \.inkTertiary)
                }
            }
            SettingsRow(label: appearance.text("settings.folders.templates"), line: false) {
                SettingsValue(text: appearance.text("settings.templates.none"), tone: \.inkTertiary)
            }
        }
    }
}

struct ImprintCard: View {
    @Environment(\.appearance) private var appearance
    let state: SettingsState

    var body: some View {
        VStack(spacing: 0) {
            ForEach(ImprintEntry.allCases, id: \.self) { entry in
                SettingsRow(label: appearance.text(entry.key)) {
                    ValueField(
                        text: Binding(get: { state.imprint[entry.rawValue] ?? "" }, set: { state.setImprint(entry, $0) }),
                        labelKey: entry.key, prompt: appearance.text(entry.promptKey))
                }
            }
        }
    }
}

struct KeyCard: View {
    @Environment(\.appearance) private var appearance
    let context: SettingsContext

    var body: some View {
        let readings = context.readings.filter { !$0.info.listsAccounts }
        VStack(spacing: 0) {
            ForEach(readings) { reading in
                SettingsRow(label: appearance.text(reading.info.nameKey)) {
                    ConnectionStatus(state: reading.state.connection, label: appearance.text(reading.state.key),
                                     trailingInset: reading.state == .notConnected)
                    if reading.state != .notConnected {
                        TextButton(label: appearance.text("text.settings.action.remove"), kind: .plain, disabled: reading.inlets.isEmpty) {
                            Task { await context.flow.remove(reading.inlets.map(\.id)) }
                        }
                    }
                }
            }
        }
    }
}

struct PrivacyCard: View {
    @Environment(\.appearance) private var appearance
    let state: SettingsState
    let privacy: AssistantPrivacy
    let conversation: ChatState

    var body: some View {
        VStack(spacing: 0) {
            SettingsRow(label: appearance.text("settings.privacy.images")) {
                ToggleSwitch(isOn: Binding(get: { state.privacy.loadImages }, set: { value in state.updatePrivacy { $0.loadImages = value } }),
                             labelKey: "settings.privacy.images")
            }
            SettingsRow(label: appearance.text("settings.privacy.assistantOff")) {
                ToggleSwitch(isOn: Binding(get: { state.privacy.assistantOff }, set: { value in turnAssistant(off: value) }),
                             labelKey: "settings.privacy.assistantOff")
            }
            SettingsRow(label: appearance.text("settings.privacy.chatFiles")) {
                ToggleSwitch(isOn: Binding(get: { state.privacy.chatFiles }, set: { value in state.updatePrivacy { $0.chatFiles = value } }),
                             labelKey: "settings.privacy.chatFiles")
            }
            BlockHead(key: "settings.privacy.categories")
            ForEach(Array(PrivacyCategory.allCases.enumerated()), id: \.element) { index, category in
                SettingsRow(label: appearance.text(category.key), line: index < PrivacyCategory.allCases.count - 1) {
                    ToggleSwitch(isOn: Binding(get: { privacy.shares(category) }, set: { privacy.set(category, shares: $0) }),
                                 labelKey: category.key)
                }
            }
        }
    }

    private func turnAssistant(off: Bool) {
        state.updatePrivacy { $0.assistantOff = off }
        if off { conversation.stop() }
    }
}
