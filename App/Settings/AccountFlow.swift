import Core
import Design
import Google
import Hub
import Mail
import Observation
import SwiftUI

enum AddStep: Equatable {
    case address
    case searching
    case found(String)
    case manual
    case renewal
}

@MainActor
@Observable
final class AccountFlow {
    private(set) var step = AddStep.address
    private(set) var needsAddress = false
    private(set) var busy = false
    private(set) var failure: Hint?
    private(set) var actedOn: String?
    private(set) var checked: Inlet.ID?
    var form: Offer?
    var values: [String: String] = [:] {
        didSet {
            if oldValue[ProviderPresets.protocolField] != values[ProviderPresets.protocolField] { applyFound() }
        }
    }

    @ObservationIgnored private let setup: any SetupPort
    @ObservationIgnored private let added: @MainActor (Inlet.ID) async -> Void
    @ObservationIgnored private var running: Task<SetupFailure?, Never>?
    @ObservationIgnored private var cancelling = false
    @ObservationIgnored private let discovery: any DiscoveryPort
    @ObservationIgnored private var finding: Task<Void, Never>?
    @ObservationIgnored private var found: [[String: String]] = []
    @ObservationIgnored private var filled: [String: String] = [:]

    init(setup: any SetupPort, discovery: any DiscoveryPort = DiscoveryClient(),
         added: @escaping @MainActor (Inlet.ID) async -> Void) {
        self.setup = setup
        self.discovery = discovery
        self.added = added
    }

    func discover() {
        finding?.cancel()
        let address = values[ProviderPresets.addressField] ?? ""
        finding = Task {
            let result = await DiscoveryEngine.choices(for: address, using: discovery)
            guard !Task.isCancelled, !result.isEmpty, values[ProviderPresets.addressField] == address else { return }
            found = result
            applyFound()
        }
    }

    var offersKinds: Bool { found.count > 1 }

    func proceed() {
        let address = (values[ProviderPresets.addressField] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let domain = DiscoveryEngine.domain(of: address) else {
            needsAddress = true
            return
        }
        needsAddress = false
        failure = nil
        values[ProviderPresets.addressField] = address
        finding?.cancel()
        found = []
        if ProviderPresets.knowsServers(form?.preset?.values) {
            step = .found(domain)
            return
        }
        step = .searching
        finding = Task {
            let result = await DiscoveryEngine.choices(for: address, using: discovery)
            guard !Task.isCancelled, step == .searching, values[ProviderPresets.addressField] == address else { return }
            found = result
            applyFound()
            step = result.isEmpty ? .manual : .found(domain)
        }
    }

    func back() {
        finding?.cancel()
        failure = nil
        step = .address
    }

    private func applyFound() {
        guard let preferred = found.first else { return }
        let preset = form?.preset?.values ?? [:]
        let untouched = { (key: String) in [nil, "", preset[key], self.filled[key]].contains(self.values[key]) }
        let field = ProviderPresets.protocolField
        let choice = untouched(field) ? preferred : (found.first { $0[field] == values[field] } ?? [:])
        var next = values
        for key in ProviderPresets.incomingFields.union(choice.keys) where untouched(key) {
            next[key] = choice[key] ?? preset[key]
        }
        filled = choice
        if next != values { values = next }
    }

    func choose(_ offer: Offer, values preset: [String: String]? = nil) async {
        failure = nil
        switch offer.way {
        case .signIn:
            await add(offer, input: preset.map { .fields($0) } ?? .none)
        case .form, .key:
            form = offer
            step = preset == nil ? .address : .renewal
            values = preset ?? offer.preset?.values ?? [:]
        }
    }

    func open(_ offers: [Offer]) {
        guard let offer = offers.first else { return }
        failure = nil
        checked = nil
        step = .address
        needsAddress = false
        form = offer
        values = offer.preset?.values ?? [:]
    }

    func select(_ offer: Offer) {
        let previous = Set(form?.preset?.values.keys.map { $0 } ?? [])
        var kept = values.filter { !previous.contains($0.key) }
        for (key, value) in offer.preset?.values ?? [:] { kept[key] = value }
        failure = nil
        needsAddress = false
        form = offer
        values = kept
    }

    func perform(_ step: IntegrationStep, for id: String) {
        actedOn = id
        checked = nil
        switch step {
        case .add(let offers):
            if let offer = offers.first { Task { await choose(offer) } }
        case .renew(let inlet):
            Task { await renew(inlet) }
        case .none:
            failure = Hint(text: "settings.setup.unavailable", detail: id == "google" ? ClientConfigStore.fileName : nil)
        }
    }

    var canCancel: Bool { running != nil }

    func cancel() {
        cancelling = true
        running?.cancel()
    }

    func renew(_ inlet: Inlet.ID) async {
        guard let renewal = setup.renewal(of: inlet) else { return }
        await choose(renewal.offer, values: renewal.values)
    }

    func add(_ offer: Offer, input: Input) async {
        guard !busy else { return }
        busy = true
        failure = nil
        checked = nil
        cancelling = false
        let work = Task { @MainActor () -> SetupFailure? in
            do throws(SetupFailure) {
                let inlet = try await self.setup.add(offer, input: input)
                await self.added(inlet.id)
                return nil
            } catch {
                return error
            }
        }
        running = work
        let outcome = await work.value
        running = nil
        if let outcome {
            failure = cancelling || outcome == .cancelled ? nil : outcome.hint
        } else {
            close()
        }
        busy = false
    }

    func probe(_ inlet: Inlet.ID) async {
        guard !busy else { return }
        busy = true
        failure = nil
        checked = nil
        do throws(SetupFailure) {
            _ = try await setup.probe(inlet)
            checked = inlet
        } catch {
            failure = error.hint
        }
        busy = false
    }

    func remove(_ inlets: [Inlet.ID]) async {
        guard !busy else { return }
        busy = true
        failure = nil
        checked = nil
        for inlet in inlets {
            do {
                try await setup.remove(inlet)
            } catch {
                failure = Hint.failed(error)
            }
        }
        busy = false
    }

    func signOut(retiring: Bool = false) async -> Bool {
        guard !busy else { return false }
        busy = true
        failure = nil
        let failed = retiring ? await SignOutEngine.retire(setup: setup) : await SignOutEngine.run(setup: setup)
        busy = false
        guard failed.isEmpty else {
            let names = failed.map { failure in
                let name = setup.inlets.first { $0.id == failure.inlet }.map { $0.account.isEmpty ? $0.title : $0.account } ?? failure.inlet
                return name + " (" + failure.reason + ")"
            }
            failure = Hint(text: SettingsKeys.failedUnknown, detail: names.joined(separator: ", "))
            return false
        }
        return true
    }

    func close() {
        finding?.cancel()
        found = []
        filled = [:]
        form = nil
        values = [:]
        failure = nil
        step = .address
        needsAddress = false
    }
}

struct AddEditor: View {
    @Environment(\.appearance) private var appearance
    @Bindable var flow: AccountFlow
    let offers: [Offer]
    let offer: Offer
    var added: (() -> Void)?
    @FocusState private var focused: Field.ID?

    private var fields: [Field] {
        switch offer.way {
        case .form(let fields), .key(let fields): fields
        case .signIn: []
        }
    }

    private var buttonKey: String {
        switch offer.way {
        case .key: "settings.action.connect"
        case .form: "text.settings.action.addAccount"
        case .signIn: "settings.signin"
        }
    }

    @State private var missing: [Field] = []

    private var ready: Bool { lacking.isEmpty }

    private var lacking: [Field] {
        switch offer.way {
        case .signIn: []
        case .form: fields.filter { ProviderPresets.requiredFields.contains($0.id) && !filled($0) }
        case .key: fields.filter { !$0.optional && !filled($0) }
        }
    }

    private var stepped: Bool {
        guard case .form = offer.way else { return false }
        return ProviderPresets.steps(Set(fields.map(\.id)))
    }

    var body: some View {
        VStack(spacing: 0) {
            if stepped { steps } else { plain }
        }
        .onAppear {
            focused = stepped ? ProviderPresets.addressField : fields.first { !$0.secret && choices(of: $0) == nil }?.id
        }
        .onChange(of: flow.values) { missing = [] }
        .onChange(of: focused) { left, _ in
            if !stepped, left == ProviderPresets.addressField { flow.discover() }
        }
    }

    @ViewBuilder
    private var plain: some View {
        providerPicker
        ForEach(fields) { field in row(field) }
        notices
        actions(primary: buttonKey, back: false)
    }

    @ViewBuilder
    private var steps: some View {
        switch flow.step {
        case .address:
            ForEach(fields.filter { $0.id == ProviderPresets.addressField }) { field in row(field) }
            providerPicker
            if flow.needsAddress {
                BlockNotice(kind: .failure, title: appearance.text("settings.add.check"), text: appearance.text("settings.account.needAddress"))
            }
            SettingsRow(label: Text(verbatim: ""), line: false) {
                HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
                    TextButton(label: appearance.text("settings.account.continue"), kind: .accent) { flow.proceed() }
                    cancelButton
                }
            }
        case .searching:
            BlockNotice(kind: .warning, title: appearance.text("settings.account.searching"), text: Text(verbatim: value(ProviderPresets.addressField)))
            SettingsRow(label: Text(verbatim: ""), line: false) { cancelButton }
        case .found(let domain):
            BlockNotice(kind: .success, title: appearance.text("settings.account.found"),
                        text: Text(verbatim: appearance.format("settings.account.foundText", domain)))
            ForEach(fields.filter(shownWhenFound)) { field in row(field) }
            notices
            actions(primary: "settings.account.signIn", back: true)
        case .manual:
            BlockNotice(kind: .warning, title: appearance.text("settings.account.notFound"), text: appearance.text("settings.account.notFoundText"))
            ForEach(fields) { field in row(field) }
            notices
            actions(primary: "settings.account.signIn", back: true)
        case .renewal:
            ForEach(fields) { field in row(field) }
            notices
            actions(primary: buttonKey, back: false)
        }
    }

    @ViewBuilder
    private var providerPicker: some View {
        if offers.count > 1 {
            SettingsRow(label: appearance.text("settings.account.provider")) {
                ChoiceButton(label: appearance.text(offer.title)) {
                    offers.map { choice in
                        .row(MenuItem(id: choice.id, label: appearance.text(choice.title),
                                      check: choice.id == offer.id ? appearance.text(SettingsKeys.menuCheck) : nil) {
                            flow.select(choice)
                        })
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var notices: some View {
        if !missing.isEmpty {
            BlockNotice(kind: .failure, title: appearance.text("settings.add.check"),
                        text: Text(verbatim: appearance.format("settings.add.missing",
                                                               missing.map { appearance.string(title($0)) }.joined(separator: ", "))))
        }
        if let failure = flow.failure {
            BlockNotice(kind: .failure, title: appearance.text("settings.add.failed.title"),
                        text: Text(verbatim: failure.line(appearance)))
        }
    }

    private func actions(primary: String, back: Bool) -> some View {
        SettingsRow(label: Text(verbatim: ""), sub: flow.busy ? appearance.text("settings.link.connecting") : nil, line: false) {
            HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
                TextButton(label: appearance.text(primary), kind: .accent, disabled: flow.busy) { submit() }
                if back {
                    TextButton(label: appearance.text("settings.account.back"), kind: .neutral, disabled: flow.busy) { flow.back() }
                }
                cancelButton
            }
        }
    }

    private var cancelButton: some View {
        TextButton(label: appearance.text("text.common.cancel"), kind: .plain) {
            if flow.busy { flow.cancel() } else { flow.close() }
        }
    }

    private func row(_ field: Field) -> some View {
        SettingsRow(label: appearance.text(title(field))) { entry(field) }
    }

    private func title(_ field: Field) -> String {
        stepped ? ProviderPresets.stepTitle(field.id) ?? field.title : field.title
    }

    private func shownWhenFound(_ field: Field) -> Bool {
        ProviderPresets.foundFields.contains(field.id) && (field.id != ProviderPresets.protocolField || flow.offersKinds)
    }

    @ViewBuilder
    private func entry(_ field: Field) -> some View {
        if let options = choices(of: field) {
            let current = options.contains(value(field.id)) ? value(field.id) : options[0]
            ChoiceButton(label: appearance.text(ProviderPresets.choiceKey(field: field.id, option: current))) {
                options.map { option in
                    .row(MenuItem(id: option, label: appearance.text(ProviderPresets.choiceKey(field: field.id, option: option)),
                                  check: option == current ? appearance.text(SettingsKeys.menuCheck) : nil) {
                        flow.values[field.id] = option
                    })
                }
            }
        } else {
            let binding = Binding(get: { flow.values[field.id] ?? "" }, set: { flow.values[field.id] = $0 })
            Group {
                if field.secret {
                    SecureField(text: binding, prompt: nil) { appearance.text(field.title) }
                } else {
                    TextField(text: binding, prompt: nil) { appearance.text(field.title) }
                }
            }
            .textFieldStyle(.plain)
            .multilineTextAlignment(.trailing)
            .font(.face(Tokens.TextSize.body))
            .foregroundStyle(appearance.color(\.ink))
            .autocorrectionDisabled()
            .focused($focused, equals: field.id)
            .onSubmit {
                if stepped, flow.step == .address {
                    flow.proceed()
                } else if !stepped, field.id == ProviderPresets.addressField, !ready {
                    flow.discover()
                } else {
                    submit()
                }
            }
            .padding(.trailing, CGFloat(Tokens.Size.trailingTextInset))
            .frame(maxWidth: .infinity)
            .frame(height: CGFloat(Tokens.Spacing.step28))
        }
    }

    private func choices(of field: Field) -> [String]? {
        ProviderPresets.choices(for: field.id)
    }

    private func value(_ id: Field.ID) -> String {
        flow.values[id] ?? ""
    }

    private func filled(_ field: Field) -> Bool {
        !value(field.id).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        missing = lacking
        guard ready, !flow.busy else { return }
        let input: Input = if case .signIn = offer.way { .none } else { .fields(flow.values) }
        Task {
            await flow.add(offer, input: input)
            if flow.form == nil { added?() }
        }
    }
}

struct AccountBlock: View {
    @Environment(\.appearance) private var appearance
    let context: SettingsContext
    let info: IntegrationInfo
    let reading: IntegrationReading
    @Binding var started: Bool

    private var flow: AccountFlow { context.flow }

    var body: some View {
        BlockHead(key: "settings.mail.compose")
        undoSend
        BlockHead(key: "settings.accounts.head")
        if let offer = flow.form, info.providers.contains(offer.provider) {
            AddEditor(flow: flow, offers: reading.offers, offer: offer, added: { context.state.notify("settings.toast.accountAdded") })
        } else if reading.inlets.isEmpty {
            BlockNotice(kind: .warning, title: appearance.text("settings.accounts.none.title")) {
                addAccount(kind: .accent)
            }
        } else {
            ForEach(reading.inlets) { inlet in
                SettingsRow(label: inlet.account.isEmpty ? appearance.text(inlet.title) : Text(verbatim: inlet.account),
                            sub: inlet.account.isEmpty ? nil : appearance.text(inlet.title),
                            line: !Self.hasMailbox(inlet)) {
                    ConnectionStatus(state: LinkState(inlet.state).connection, label: appearance.text(LinkState(inlet.state).key))
                    TextButton(label: appearance.text("text.settings.action.check"), kind: .plain, disabled: flow.busy) {
                        started = true
                        Task { await flow.probe(inlet.id) }
                    }
                }
                if Self.hasMailbox(inlet) {
                    MailboxNameRow(state: context.state, inlet: inlet)
                    MailboxDisplayRow(state: context.state, inlet: inlet)
                    MailboxImagesRow(state: context.state, inlet: inlet)
                    MailboxServerCopyRow(state: context.state, inbox: context.inbox, inlet: inlet)
                    SignatureBlock(state: context.state, inlet: inlet)
                }
                SettingsRow(label: appearance.text("settings.account.remove")) {
                    ConfirmPill(
                        label: appearance.text("text.settings.action.remove"),
                        question: Text(verbatim: [appearance.string("settings.account.remove.ask"),
                                                  Self.waiting([inlet.id], context: context, appearance: appearance)]
                            .compactMap { $0 }.joined(separator: " ")),
                        yes: appearance.text("text.settings.action.remove"),
                        no: appearance.text("confirm.no"),
                        holdHint: appearance.text("settings.hold.remove"),
                        showsProgress: false,
                        onYes: {
                            started = true
                            Task { await flow.remove([inlet.id]) }
                        }
                    )
                    .rowPill()
                }
            }
            SettingsRow(label: Text(verbatim: ""), line: false) {
                addAccount(kind: .neutral)
            }
        }
    }

    static func hasMailbox(_ inlet: Inlet) -> Bool {
        inlet.capabilities.contains(.mail)
    }

    static func waiting(_ inlets: [Inlet.ID], context: SettingsContext, appearance: Appearance) -> String? {
        let count = inlets.reduce(0) { $0 + context.inbox.unsent($1) }
        let local = inlets.contains(where: context.inbox.inboxOnly) ? appearance.string("settings.disconnect.local") : nil
        let unsent = count == 0 ? nil : count == 1 ? appearance.string("settings.disconnect.waiting.one")
            : appearance.format("settings.disconnect.waiting.other", Format.number(count))
        let text = [local, unsent].compactMap { $0 }.joined(separator: " ")
        return text.isEmpty ? nil : text
    }

    private var undoSend: some View {
        let current = context.state.undoSend
        return SettingsRow(label: appearance.text("settings.mail.undoSend")) {
            ChoiceButton(label: Text(verbatim: label(current))) {
                UndoSend.allCases.map { option in
                    .row(MenuItem(id: option.rawValue, label: Text(verbatim: label(option)),
                                  check: option == current ? appearance.text(SettingsKeys.menuCheck) : nil) {
                        context.state.setUndoSend(option)
                    })
                }
            }
        }
    }

    private func label(_ option: UndoSend) -> String {
        guard option != .off else { return appearance.string("settings.mail.undoOff") }
        return Duration.seconds(option.seconds).formatted(.units(allowed: [.seconds], width: .narrow).locale(appearance.locale))
    }

    private func addAccount(kind: TextButtonKind) -> some View {
        TextButton(label: appearance.text("text.settings.action.addAccount"), kind: kind, disabled: flow.busy || reading.offers.isEmpty) {
            started = true
            flow.open(reading.offers)
        }
    }
}
