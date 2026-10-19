import AppKit
import Hub
import ShellCore
import SwiftUI

struct SettingsCardBody: View {
    @Bindable var host: AppHost
    let board: SettingsBoard
    let hub: Hub
    let id: String

    var body: some View {
        if let info = ServiceCatalog.info(id) {
            ServiceCardBody(host: host, board: board, hub: hub, info: info)
        } else if let section = SettingsSection(rawValue: id) {
            switch section {
            case .identity: IdentityCard(host: host, hub: hub)
            case .appearance: AppearanceCard()
            case .companyData: CompanyCard()
            case .folders: FoldersCard()
            case .templates: TemplatesCard()
            case .integrations: EmptyView()
            case .keyInventory: KeyInventoryCard(host: host, hub: hub)
            case .privacy: PrivacyCard()
            case .system: SystemCard(board: board)
            case .imprint: ImprintCard()
            }
        }
    }
}

private struct SettingsValueField: View {
    @Environment(\.design) private var design
    @Binding var text: String
    let labelKey: String
    var prompt: Text?

    var body: some View {
        TextField(text: $text, prompt: prompt?.foregroundStyle(design.color(\.inkTertiary))) { word(labelKey) }
            .textFieldStyle(.plain)
            .multilineTextAlignment(.trailing)
            .font(.face(Design.TextSize.body))
            .foregroundStyle(design.color(\.ink))
            .autocorrectionDisabled()
            .padding(.trailing, CGFloat(Design.Size.trailingTextInset))
            .frame(maxWidth: .infinity)
            .frame(height: CGFloat(Design.Spacing.step28))
    }
}

private struct SettingsSwitchRow: View {
    let labelKey: String
    var subKey: String?
    var line = true
    @Binding var isOn: Bool

    var body: some View {
        SettingsRow(label: word(labelKey), sub: subKey.map { word($0) }, line: line) {
            ToggleSwitch(isOn: $isOn, labelKey: labelKey)
        }
    }
}

private struct SettingsChoiceRow<Choice: Hashable>: View {
    let labelKey: String
    var line = true
    let current: Choice
    let choices: [Choice]
    let key: (Choice) -> String
    let pick: (Choice) -> Void

    var body: some View {
        SettingsRow(label: word(labelKey), line: line) {
            SettingsMenuChoice(label: word(key(current))) {
                choices.map { choice in
                    .row(MenuItem(id: key(choice), label: word(key(choice)), check: choice == current ? Text(Image(systemName: "checkmark")) : nil) {
                        pick(choice)
                    })
                }
            }
        }
    }
}

private struct SettingsDisabledButton: View {
    let labelKey: String
    var kind = TextButtonKind.neutral

    var body: some View {
        TextButton(label: word(labelKey), kind: kind, disabled: true) {}
            .opacity(SheetValues.disabledOpacity)
    }
}

private struct IdentityCard: View {
    @Bindable var host: AppHost
    let hub: Hub
    @AppStorage(SettingsKey.identityName) private var name = ""
    @AppStorage(SettingsKey.identityRole) private var role = ""
    @AppStorage(SettingsKey.identityCode) private var code = ""
    @AppStorage(SettingsKey.identityPhone) private var phone = ""
    @AppStorage(SettingsKey.birthdays) private var birthdays = false

    var body: some View {
        VStack(spacing: 0) {
            SettingsRow(label: word("settings.identity.name")) {
                SettingsValueField(text: $name, labelKey: "settings.identity.name", prompt: word("settings.value.empty"))
            }
            SettingsRow(label: word("settings.identity.role")) {
                SettingsValueField(text: $role, labelKey: "settings.identity.role", prompt: word("settings.value.empty"))
            }
            SettingsRow(label: word("settings.identity.code")) {
                SettingsValueField(
                    text: $code, labelKey: "settings.identity.code",
                    prompt: SettingsFormat.initials(name).isEmpty ? word("settings.value.empty") : Text(verbatim: SettingsFormat.initials(name)))
            }
            SettingsRow(label: word("settings.identity.phone")) {
                SettingsValueField(text: $phone, labelKey: "settings.identity.phone", prompt: word("settings.value.empty"))
            }
            SettingsSwitchRow(labelKey: "settings.identity.birthdays", isOn: $birthdays)
            SettingsBlockHead(key: "settings.identity.account")
            SettingsRow(label: word("settings.identity.signOut"), sub: word("settings.identity.signOut.sub"), line: false) {
                TextButton(label: word("settings.identity.signOut.action"), kind: .signal) { signOut() }
            }
        }
    }

    private func signOut() {
        Task {
            for inlet in hub.setup.inlets { await host.remove(inlet.id) }
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.createsNewApplicationInstance = true
            _ = try? await NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration)
            NSApp.terminate(nil)
        }
    }
}

private struct AppearanceCard: View {
    @AppStorage(SettingsKey.appearance) private var appearance = AppearanceChoice.system.rawValue
    @AppStorage(SettingsKey.startView) private var start = StartView.mail.rawValue
    @AppStorage(SettingsKey.lockOn) private var lockOn = false
    @AppStorage(SettingsKey.lockDelay) private var delay = LockDelay.minutes5.rawValue

    var body: some View {
        VStack(spacing: 0) {
            SettingsRow(label: word("settings.appearance.label")) {
                SegmentedControl(
                    options: AppearanceChoice.allCases.map { SegmentOption(id: $0, label: word($0.key)) },
                    selection: Binding(get: { AppearanceChoice(rawValue: appearance) ?? .system }, set: { appearance = $0.rawValue }))
            }
            SettingsRow(label: word("settings.appearance.foreign"), sub: word("settings.appearance.foreign.sub")) {
                SettingsValue(text: word("settings.appearance.foreign.value"))
            }
            SettingsChoiceRow(
                labelKey: "settings.start.label", current: StartView(rawValue: start) ?? .mail, choices: StartView.allCases,
                key: { $0.key }, pick: { start = $0.rawValue })
            SettingsSwitchRow(labelKey: "settings.lock.label", subKey: "settings.lock.sub", isOn: $lockOn)
            SettingsChoiceRow(
                labelKey: "settings.lock.after", current: LockDelay(rawValue: delay) ?? .minutes5, choices: LockDelay.allCases,
                key: { $0.key }, pick: { delay = $0.rawValue })
        }
    }
}

private struct CompanyCard: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(CompanyRow.allCases, id: \.self) { row in
                StoredValueRow(labelKey: row.key, storageKey: SettingsKey.companyRow(row.rawValue))
            }
        }
    }
}

private struct ImprintCard: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(ImprintRow.allCases, id: \.self) { row in
                StoredValueRow(labelKey: row.key, storageKey: SettingsKey.imprintRow(row.rawValue))
            }
        }
    }
}

private struct StoredValueRow: View {
    let labelKey: String
    let storageKey: String
    @AppStorage private var text: String

    init(labelKey: String, storageKey: String) {
        self.labelKey = labelKey
        self.storageKey = storageKey
        _text = AppStorage(wrappedValue: "", storageKey)
    }

    var body: some View {
        SettingsRow(label: word(labelKey)) {
            SettingsValueField(text: $text, labelKey: labelKey)
        }
    }
}

private struct FoldersCard: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(["settings.folders.projects", "settings.folders.data", "settings.folders.templates"], id: \.self) { key in
                SettingsRow(label: word(key)) {
                    SettingsValue(text: word("settings.value.empty"), tone: \.inkTertiary)
                }
            }
            SettingsRow(label: word("settings.folders.setup"), line: false) {
                SettingsDisabledButton(labelKey: "settings.folders.setup.action")
            }
        }
    }
}

private struct TemplatesCard: View {
    var body: some View {
        VStack(spacing: 0) {
            SettingsBlockNote(text: word("settings.templates.none"))
            SettingsRow(label: word("settings.templates.create"), line: false) {
                SettingsDisabledButton(labelKey: "settings.templates.create.action")
            }
        }
    }
}

private struct KeyInventoryCard: View {
    @Bindable var host: AppHost
    let hub: Hub

    var body: some View {
        let readings = ServiceReader.readAll(setup: hub.setup, rules: hub.rules).filter { !$0.info.listsAccounts }
        VStack(spacing: 0) {
            ForEach(readings) { reading in
                SettingsRow(label: word(reading.info.nameKey)) {
                    ServiceStatus(state: reading.state.service, label: word(reading.state.key), trailingInset: reading.state == .notConnected)
                    if reading.state != .notConnected {
                        ConfirmPill(
                            label: word("text.settings.action.remove"),
                            question: Text(verbatim: SettingsFormat.text("settings.disconnect.ask", String(localized: String.LocalizationValue(reading.info.nameKey)))),
                            yes: word("text.settings.action.remove"),
                            no: word("text.common.cancel"),
                            holdHint: word("settings.hold.remove"),
                            showsProgress: false,
                            onYes: { Task { for inlet in reading.inlets { await host.remove(inlet.id) } } })
                    }
                }
            }
        }
    }
}

private struct PrivacyCard: View {
    @AppStorage(SettingsKey.loadImages) private var images = false
    @AppStorage(SettingsKey.assistantOff) private var assistantOff = false
    @AppStorage(SettingsKey.chatFiles) private var chatFiles = true

    var body: some View {
        VStack(spacing: 0) {
            SettingsSwitchRow(labelKey: "settings.privacy.images", subKey: images ? "settings.privacy.images.on" : "settings.privacy.images.off", isOn: $images)
            SettingsSwitchRow(labelKey: "settings.privacy.assistantOff", subKey: "settings.privacy.assistantOff.sub", isOn: $assistantOff)
            SettingsSwitchRow(labelKey: "settings.privacy.chatFiles", subKey: "settings.privacy.chatFiles.sub", isOn: $chatFiles)
            SettingsRow(label: word("settings.privacy.export"), line: false) {
                SettingsDisabledButton(labelKey: "settings.privacy.export.action")
            }
        }
    }
}

private struct SystemCard: View {
    let board: SettingsBoard

    private var version: String {
        let info = Bundle.main
        let short = info.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = info.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return SettingsFormat.text("settings.system.version.format", short, build)
    }

    private var database: String {
        guard let size = HubDatabase.size() else { return String(localized: "settings.value.empty") }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }

    var body: some View {
        VStack(spacing: 0) {
            SettingsRow(label: word(SettingsLabel.version.key)) { SettingsValue(text: Text(verbatim: version)) }
            SettingsRow(label: word(SettingsLabel.database.key)) { SettingsValue(text: Text(verbatim: database)) }
            SettingsRow(label: word(SettingsLabel.diagnosis.key), line: false) {
                TextButton(label: word("settings.system.copy")) { copy() }
            }
        }
    }

    private func copy() {
        let lines = [
            String(localized: String.LocalizationValue(SettingsLabel.version.key)) + ": " + version,
            String(localized: String.LocalizationValue(SettingsLabel.database.key)) + ": " + database
        ]
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
        board.notify("settings.toast.copied")
    }
}
