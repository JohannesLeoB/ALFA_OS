import AppKit
import Assistant
import Google
import Hub
import SwiftUI
import UniformTypeIdentifiers

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
            case .folders: FoldersCard(context: context)
            case .templates: TemplatesCard(state: context.state)
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
    let state: SettingsState
    @State private var failed = false

    var body: some View {
        VStack(spacing: 0) {
            if state.templates.isEmpty { BlockNote(text: appearance.text("settings.templates.none")) }
            ForEach(state.templates) { template in
                SettingsRow(label: Text(verbatim: template.name)) {
                    ConfirmPill(
                        label: appearance.text("settings.templates.remove"),
                        question: appearance.text("settings.templates.remove.question"),
                        yes: appearance.text("settings.templates.remove"),
                        no: appearance.text("confirm.no"),
                        holdHint: Text(verbatim: appearance.format("settings.confirm.hold", appearance.string("settings.templates.remove"))),
                        showsProgress: false,
                        onYes: { remove(template) }
                    )
                    .rowPill()
                }
            }
            if failed {
                BlockNotice(kind: .failure, title: appearance.text(SettingsKeys.failedUnknown), text: nil)
            }
            SettingsRow(label: appearance.text("settings.templates.create"), line: false) {
                TextButton(label: appearance.text("settings.templates.add"), kind: .neutral) { add() }
            }
        }
    }

    private func add() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = TemplateStore.extensions.compactMap { UTType(filenameExtension: $0) }
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        failed = !state.addTemplate(from: url)
    }

    private func remove(_ template: TemplateStore.Template) {
        failed = !state.removeTemplate(template)
    }
}

struct CompanyCard: View {
    @Environment(\.appearance) private var appearance
    let state: SettingsState

    var body: some View {
        VStack(spacing: 0) {
            ForEach(CompanyEntry.allCases, id: \.self) { entry in
                SettingsRow(label: appearance.text(entry.key), line: entry != CompanyEntry.allCases.last) {
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
    let context: SettingsContext

    var body: some View {
        let source = context.readings.first { $0.info.id == "airtable" && $0.state == .connected }
        VStack(spacing: 0) {
            if let choice = rootChoice {
                ProjectRootRows(context: context, info: choice.info, extra: choice.extra, inlet: choice.inlet)
            } else {
                row("settings.folders.projects", context.roots.current().map { Text(verbatim: $0.name) })
            }
            row("settings.folders.data", source.map { appearance.text($0.info.nameKey) })
            SettingsRow(label: appearance.text("settings.folders.templates"), line: false) {
                if let template = context.state.currentTemplate {
                    SettingsValue(text: Text(verbatim: template.name))
                } else {
                    SettingsValue(text: appearance.text("settings.templates.none"), tone: \.inkTertiary)
                }
            }
        }
    }

    private var rootChoice: (info: IntegrationInfo, extra: IntegrationExtra, inlet: Inlet)? {
        for reading in context.readings where reading.state == .connected {
            for extra in reading.info.extras where extra.kind == .projectRoot {
                if let inlet = reading.inlets.first(where: { extra.capability.map($0.capabilities.contains) ?? false }) {
                    return (reading.info, extra, inlet)
                }
            }
        }
        return nil
    }

    private func row(_ key: String, _ value: Text?) -> some View {
        SettingsRow(label: appearance.text(key)) {
            if let value {
                SettingsValue(text: value)
            } else {
                SettingsValue(text: appearance.text(SettingsKeys.valueEmpty), tone: \.inkTertiary)
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
                SettingsRow(label: appearance.text(entry.key), line: entry != ImprintEntry.allCases.last) {
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
                    ConnectionStatus(state: reading.state.connection, label: appearance.text(reading.state.key))
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
    @State private var exporter = ExportState()

    private var categories: [PrivacyCategory] {
        PrivacyCategory.allCases.filter { conversation.availableCategories.contains($0) || !privacy.shares($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            SettingsRow(label: appearance.text("settings.privacy.images"),
                        sub: appearance.text(state.privacy.loadImages ? "settings.privacy.images.on" : "settings.privacy.images.off")) {
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
            if exporter.canRun {
                SettingsRow(label: appearance.text("settings.privacy.export")) {
                    TextButton(label: appearance.text("settings.privacy.export.action"), kind: .neutral, disabled: exporter.running) {
                        chooseExport()
                    }
                }
            }
            BlockHead(key: "settings.privacy.categories")
            ForEach(Array(categories.enumerated()), id: \.element) { index, category in
                SettingsRow(label: appearance.text(category.key), line: index < categories.count - 1) {
                    ToggleSwitch(isOn: Binding(get: { privacy.shares(category) }, set: { privacy.set(category, shares: $0) }),
                                 labelKey: category.key)
                }
            }
        }
    }

    private func chooseExport() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.zip]
        panel.nameFieldStringValue = exporter.fileName
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await runExport(to: url) }
    }

    private func runExport(to url: URL) async {
        if await exporter.run(to: url) {
            state.notify("settings.toast.exportSaved")
        } else {
            state.notify("settings.toast.exportFailed", failed: true) { chooseExport() }
        }
    }

    private func turnAssistant(off: Bool) {
        state.updatePrivacy { $0.assistantOff = off }
        if off { conversation.stop() }
    }
}
