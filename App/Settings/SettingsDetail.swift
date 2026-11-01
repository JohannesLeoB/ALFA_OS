import AppKit
import Assistant
import Core
import Design
import Google
import Hub
import Mail
import Observation
import Storage
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
                        label: appearance.text("settings.contacts.remove"),
                        question: appearance.text("settings.templates.remove.question"),
                        yes: appearance.text("settings.contacts.remove"),
                        no: appearance.text("confirm.no"),
                        holdHint: Text(verbatim: appearance.format("settings.confirm.hold", appearance.string("settings.contacts.remove"))),
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
        panel.appearance = ForeignContent.panel
        panel.allowedContentTypes = TemplateStore.extensions.compactMap { UTType(filenameExtension: $0) }
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        failed = !state.addTemplate(from: url)
    }

    private func remove(_ template: TemplateFile) {
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
            row("settings.folders.projects", context.roots.current().map { Text(verbatim: $0.name) })
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
                row(reading)
            }
        }
    }

    private func row(_ reading: IntegrationReading) -> some View {
        let flow = context.flow
        let failure = flow.actedOn == reading.info.id ? flow.failure : nil
        return SettingsRow(label: appearance.text(reading.info.nameKey),
                           sub: failure.map { Text(verbatim: appearance.format("settings.failed.title", $0.line(appearance))) }) {
            ConnectionStatus(state: reading.state.connection, label: appearance.text(reading.state.key))
            if reading.state == .notConnected {
                TextButton(label: appearance.text("settings.action.connect"), kind: .accent, disabled: flow.busy) {
                    context.state.open(reading.info.id)
                    flow.perform(reading.step, for: reading.info.id)
                }
            } else if !reading.inlets.isEmpty {
                ConfirmPill(
                    label: appearance.text("settings.contacts.remove"),
                    question: Text(verbatim: question(reading)),
                    yes: appearance.text("settings.contacts.remove"),
                    no: appearance.text("confirm.no"),
                    holdHint: appearance.text("settings.hold.remove"),
                    showsProgress: false,
                    onYes: {
                        flow.claim(reading.info.id)
                        Task { await flow.remove(reading.inlets.map(\.id)) }
                    }
                )
                .rowPill()
            }
        }
        .help(failure?.detail ?? "")
    }

    private func question(_ reading: IntegrationReading) -> String {
        [appearance.format("settings.disconnect.ask", appearance.string(reading.info.nameKey)),
         AccountBlock.waiting(reading.inlets.map(\.id), context: context, appearance: appearance)]
            .compactMap { $0 }.joined(separator: " ")
    }
}

struct PrivacyCard: View {
    @Environment(\.appearance) private var appearance
    let state: SettingsState
    let privacy: AssistantPrivacy
    let conversation: ChatState
    @State private var exporter = ExportState(port: ExportStore())

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
                    ToggleSwitch(isOn: Binding(get: { privacy.shares(category) }, set: { share(category, $0) }),
                                 labelKey: category.key)
                }
            }
            if !privacy.readable {
                BlockNotice(kind: .failure, title: appearance.text(SettingsKeys.failedUnknown), text: nil)
            }
        }
    }

    private func share(_ category: PrivacyCategory, _ shares: Bool) {
        do {
            try privacy.set(category, shares: shares)
        } catch {
            state.notify(SettingsKeys.failedUnknown, failed: true)
        }
    }

    private func chooseExport() {
        let panel = NSSavePanel()
        panel.appearance = ForeignContent.panel
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

struct AppearanceCard: View {
    @Environment(\.appearance) private var appearance
    @Environment(\.narrowCard) private var narrow
    @Environment(\.session) private var session
    let state: SettingsState

    var body: some View {
        VStack(spacing: 0) {
            if narrow {
                ChoiceRow(
                    labelKey: "settings.appearance.label", current: state.appearance, choices: AppearanceChoice.allCases,
                    key: { $0.key }, pick: { state.setAppearance($0) })
            } else {
                SettingsRow(label: appearance.text("settings.appearance.label")) {
                    SegmentedControl(
                        options: AppearanceChoice.allCases.map { SegmentOption(id: $0, label: appearance.text($0.key)) },
                        selection: Binding(get: { state.appearance }, set: { state.setAppearance($0) }))
                }
            }
            SettingsRow(label: appearance.text("settings.appearance.foreign"), line: false) {
                SettingsValue(text: appearance.text("settings.appearance.foreign.value"))
            }
            ChoiceRow(
                labelKey: "settings.start.label", line: false, current: state.destination, choices: StartDestination.allCases,
                key: { $0.key }, pick: { state.setDestination($0) })
            if session?.lock.available ?? true {
                SettingsRow(label: appearance.text("settings.lock.label")) {
                    ToggleSwitch(isOn: Binding(get: { state.lockOn }, set: { state.setLockOn($0) }), labelKey: "settings.lock.label")
                }
                ChoiceRow(
                    labelKey: "settings.lock.after", line: false, current: state.lockDelay, choices: LockDelay.allCases,
                    key: { $0.key }, pick: { state.setLockDelay($0) })
            }
        }
    }
}

struct ChoiceRow<Choice: Hashable>: View {
    @Environment(\.appearance) private var appearance
    let labelKey: String
    var line = true
    let current: Choice
    let choices: [Choice]
    let key: (Choice) -> String
    let pick: (Choice) -> Void

    var body: some View {
        SettingsRow(label: appearance.text(labelKey), line: line) {
            ChoiceButton(label: appearance.text(key(current))) {
                choices.map { choice in
                    .row(MenuItem(id: key(choice), label: appearance.text(key(choice)),
                                  check: choice == current ? appearance.text(SettingsKeys.menuCheck) : nil) {
                        pick(choice)
                    })
                }
            }
        }
    }
}

extension AppearanceChoice {
    var scheme: ColorScheme? {
        switch self {
        case .light: .light
        case .dark: .dark
        case .system: nil
        }
    }

}

enum ForeignContent {
    static var panel: NSAppearance? { NSAppearance(named: .aqua) }
}

struct ContactCard: View {
    @Environment(\.appearance) private var appearance
    let context: SettingsContext

    private var contacts: ContactState { context.inbox.contacts }

    private var directory: ContactSourceState { context.inbox.directory }

    private var sources: [ContactSource] {
        directory.feeds.map(\.source) + (context.inbox.accounts.isEmpty ? [] : [ContactSource.mail])
    }

    var body: some View {
        let suggested = context.inbox.senderSuggestions
        VStack(spacing: 0) {
            if !sources.isEmpty {
                BlockHead(key: "settings.contacts.sources")
                ForEach(Array(sources.enumerated()), id: \.element.id) { index, source in
                    SettingsRow(label: appearance.text(source.kind.key),
                                sub: source.account.isEmpty ? nil : Text(verbatim: source.account), line: index < sources.count - 1) {
                        ToggleSwitch(isOn: Binding(get: { directory.isOn(source.id) }, set: { turn(source, $0) }), labelKey: source.kind.key)
                    }
                }
                BlockHead(key: "settings.contacts.saved")
            }
            ForEach(contacts.items) { contact in
                if contacts.editing == contact.id {
                    SettingsRow(label: appearance.text("settings.contacts.name")) {
                        ValueField(text: Binding(get: { contact.name }, set: { contacts.edit(contact.id, name: $0) }),
                                   labelKey: "settings.contacts.name")
                    }
                    SettingsRow(label: appearance.text("settings.contacts.address")) {
                        ValueField(text: Binding(get: { contact.address }, set: { contacts.edit(contact.id, address: $0) }),
                                   labelKey: "settings.contacts.address")
                    }
                    SettingsRow(label: Text(verbatim: "")) {
                        TextButton(label: appearance.text("settings.contacts.done"), kind: .accent) { contacts.editing = nil }
                        TextButton(label: appearance.text("settings.contacts.remove"), kind: .signal) { notify(contacts.remove(contact.id)) }
                    }
                } else {
                    SettingsRow(label: contact.name.isEmpty ? appearance.text("settings.contacts.unnamed") : Text(verbatim: contact.name),
                                sub: contact.address.isEmpty ? appearance.text("settings.contacts.noAddress") : Text(verbatim: contact.address)) {
                        TextButton(label: appearance.text("settings.contacts.edit")) { contacts.editing = contact.id }
                    }
                }
            }
            SettingsRow(label: appearance.text("settings.contacts.new"), line: !suggested.isEmpty) {
                TextButton(label: appearance.text("settings.contacts.add")) { contacts.add() }
            }
            if !suggested.isEmpty {
                BlockNote(text: appearance.text("settings.contacts.suggested"))
                ForEach(Array(suggested.enumerated()), id: \.element.id) { index, item in
                    SettingsRow(label: Text(verbatim: item.name.isEmpty ? item.address : item.name), sub: Text(verbatim: item.address),
                                line: index < suggested.count - 1) {
                        TextButton(label: appearance.text("settings.contacts.keep")) { notify(context.inbox.saveContact(item)) }
                    }
                }
            }
        }
    }

    private func turn(_ source: ContactSource, _ on: Bool) {
        do {
            try directory.set(source.id, on: on)
        } catch {
            context.state.notify(SettingsKeys.failedUnknown, failed: true)
            return
        }
        if on {
            Task {
                if await !directory.refresh() { context.state.notify(SettingsKeys.failedUnknown, failed: true) }
            }
        }
    }

    private func notify(_ kind: ToastKind) {
        context.state.notify(kind.key, name: kind.name)
    }
}

struct IdentityCard: View {
    @Environment(\.appearance) private var appearance
    let context: SettingsContext
    @State private var refused: Hint?

    private var profile: UserProfile { context.state.profile }

    var body: some View {
        VStack(spacing: 0) {
            SettingsRow(label: appearance.text("settings.identity.name")) {
                ValueField(text: bind(\.name), labelKey: "settings.identity.name", prompt: appearance.text(SettingsKeys.valueEmpty),
                           onEnd: { context.state.finishProfile() })
            }
            SettingsRow(label: appearance.text("settings.identity.role")) {
                ValueField(text: bind(\.role), labelKey: "settings.identity.role", prompt: appearance.text(SettingsKeys.valueEmpty),
                           onEnd: { context.state.finishProfile() })
            }
            SettingsRow(label: appearance.text("settings.identity.code")) {
                ValueField(
                    text: bind(\.code), labelKey: "settings.identity.code",
                    prompt: Initials.from(profile.name).isEmpty ? appearance.text(SettingsKeys.valueEmpty) : Text(verbatim: Initials.from(profile.name)))
            }
            SettingsRow(label: appearance.text("settings.identity.phone")) {
                ValueField(text: bind(\.phone), labelKey: "settings.identity.phone", prompt: appearance.text(SettingsKeys.valueEmpty))
            }
            SettingsRow(label: appearance.text("settings.identity.birthdays")) {
                ToggleSwitch(
                    isOn: Binding(get: { profile.birthdays }, set: { value in context.state.updateProfile { $0.birthdays = value } }),
                    labelKey: "settings.identity.birthdays")
            }
            BlockHead(key: "settings.identity.account")
            SettingsRow(label: appearance.text("settings.identity.signOut"), sub: Text(verbatim: signOutSub)) {
                ConfirmPill(
                    label: appearance.text("settings.identity.signOut.action"),
                    question: appearance.text("settings.signOut.question"),
                    yes: appearance.text("settings.identity.signOut.action"),
                    no: appearance.text("confirm.no"),
                    holdHint: Text(verbatim: appearance.format("settings.confirm.hold", appearance.string("settings.identity.signOut.action"))),
                    showsProgress: false,
                    onYes: { signOut(retiring: false) }
                )
                .rowPill()
            }
            SettingsRow(label: appearance.text("settings.identity.retire"), sub: appearance.text("settings.identity.retire.sub"), line: false) {
                ConfirmPill(
                    label: appearance.text("settings.identity.retire.action"),
                    question: appearance.text("settings.retire.question"),
                    yes: appearance.text("settings.identity.retire.action"),
                    no: appearance.text("confirm.no"),
                    holdHint: Text(verbatim: appearance.format("settings.confirm.hold", appearance.string("settings.identity.retire.action"))),
                    showsProgress: false,
                    onYes: { signOut(retiring: true) }
                )
                .rowPill()
            }
            if let refused {
                BlockNotice(kind: .failure, title: Text(verbatim: appearance.format("settings.failed.title", refused.line(appearance))))
                    .help(refused.detail ?? "")
            }
        }
    }

    private var signOutSub: String {
        let names = context.readings
            .filter { [.connected, .working, .failed, .connecting].contains($0.state) }
            .map { appearance.string($0.info.nameKey) }
        switch names.count {
        case 0: return appearance.string("settings.identity.signOut.sub.none")
        case 1: return appearance.format("settings.identity.signOut.sub.one", names[0])
        default: return appearance.format("settings.identity.signOut.sub.other", String(names.count), names.joined(separator: ", "))
        }
    }

    private func bind(_ path: WritableKeyPath<UserProfile, String>) -> Binding<String> {
        Binding(get: { profile[keyPath: path] }, set: { value in context.state.updateProfile { $0[keyPath: path] = value } })
    }

    private func signOut(retiring: Bool) {
        Task {
            refused = nil
            guard await context.flow.signOut(retiring: retiring) else {
                refused = context.flow.failure
                return
            }
            context.state.notify(retiring ? "settings.retire.done" : "settings.signOut.done")
            try? await Task.sleep(for: .seconds(Tokens.Duration.toast))
            if let error = await AppRelaunch.run() {
                refused = Hint(text: SettingsKeys.failedUnknown, detail: error.localizedDescription)
            }
        }
    }
}

enum AppRelaunch {
    @MainActor
    static func run() async -> (any Error)? {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        do {
            _ = try await NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration)
        } catch {
            return error
        }
        NSApp.terminate(nil)
        return nil
    }
}

struct SystemCard: View {
    @Environment(\.appearance) private var appearance
    let state: SettingsState

    private var version: String {
        let info = Bundle.main
        let short = info.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = info.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return appearance.format("settings.system.version.format", short, build)
    }

    private var branch: String? {
        let info = Bundle.main
        guard let name = info.object(forInfoDictionaryKey: "ALFABranch") as? String, !name.isEmpty,
              let commit = info.object(forInfoDictionaryKey: "ALFACommit") as? String, !commit.isEmpty else { return nil }
        return appearance.format("settings.system.branch.format", name, commit)
    }

    private var database: String {
        guard let size = DatabaseStore.size() else { return appearance.string(SettingsKeys.valueEmpty) }
        return Format.bytes(size)
    }

    var body: some View {
        VStack(spacing: 0) {
            SettingsRow(label: appearance.text(SettingsLabel.version.key)) { SettingsValue(text: Text(verbatim: version), compact: true) }
            if let branch {
                SettingsRow(label: appearance.text(SettingsLabel.branch.key)) { SettingsValue(text: Text(verbatim: branch), compact: true) }
            }
            SettingsRow(label: appearance.text(SettingsLabel.database.key)) { SettingsValue(text: Text(verbatim: database)) }
            SettingsRow(label: appearance.text(SettingsLabel.diagnosis.key), line: false) {
                TextButton(label: appearance.text("settings.system.copy")) { copy() }
            }
        }
    }

    private func copy() {
        var lines = [line(.version, version)]
        if let branch { lines.append(line(.branch, branch)) }
        lines.append(line(.database, database))
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
        state.notify("settings.toast.copied")
    }

    private func line(_ label: SettingsLabel, _ value: String) -> String {
        appearance.format("settings.system.line", appearance.string(label.key), value)
    }
}

@MainActor
@Observable
final class AssistantPrivacy {
    private(set) var settings: PrivacySettings
    private(set) var readable: Bool

    @ObservationIgnored private let store: PrivacyStore

    init(store: PrivacyStore) {
        self.store = store
        (settings, readable) = store.current()
    }

    func shares(_ category: PrivacyCategory) -> Bool { settings.shares(category) }

    func set(_ category: PrivacyCategory, shares: Bool) throws {
        var next = settings
        if shares { next.disabled.remove(category) } else { next.disabled.insert(category) }
        try store.save(next)
        settings = next
        readable = true
    }
}
