import Hub
import ShellCore
import SwiftUI

struct SettingsBlockHead: View {
    @Environment(\.design) private var design
    let key: String

    var body: some View {
        word(key)
            .font(.face(Design.TextSize.small))
            .foregroundStyle(design.color(\.inkTertiary))
            .padding(.horizontal, CGFloat(Design.Spacing.step16))
            .padding(.bottom, CGFloat(Design.Spacing.step8))
            .frame(maxWidth: .infinity, minHeight: CGFloat(Design.Spacing.step36), alignment: .bottomLeading)
    }
}

struct SettingsBlockNote: View {
    @Environment(\.design) private var design
    let text: Text

    var body: some View {
        text
            .font(.face(Design.TextSize.small))
            .foregroundStyle(design.color(\.inkTertiary))
            .lineHeight(Design.LineHeight.small, size: Design.TextSize.small)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, CGFloat(Design.Spacing.step16))
            .padding(.vertical, CGFloat(Design.Spacing.step8))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsBlockNotice<Actions: View>: View {
    let kind: NoticeKind
    let title: Text
    let text: Text
    @ViewBuilder let actions: Actions

    var body: some View {
        Notice(kind: kind, title: title, text: text) {
            Glyph(kind == .success ? .check : .alert)
        } actions: {
            actions
        }
        .padding(.horizontal, CGFloat(Design.Spacing.step8))
        .padding(.vertical, CGFloat(Design.Spacing.step4))
    }
}

struct ServiceCardBody: View {
    @Bindable var host: AppHost
    let board: SettingsBoard
    let hub: Hub
    let info: ServiceInfo
    var disconnecting = false
    @State private var revision = 0
    @State private var started = false

    private var reading: ServiceReading {
        _ = revision
        return ServiceReader.read(info, setup: hub.setup, rules: hub.rules)
    }

    private var name: String { String(localized: String.LocalizationValue(info.nameKey)) }

    var body: some View {
        let reading = reading
        VStack(spacing: 0) {
            progress
            SettingsRow(label: word("settings.row.state"), sub: note(reading.note)) {
                ServiceStatus(state: reading.state.service, label: word(reading.state.key), trailingInset: true)
            }
            notices(reading)
            if disconnecting { SettingsBlockNote(text: Text(verbatim: SettingsFormat.text("settings.disconnect.text", name))) }
            accounts(reading)
            SettingsRow(label: word("settings.row.access")) {
                SettingsValue(text: Text(verbatim: access))
            }
            ForEach(info.fields, id: \.id) { field in
                let empty = reading.state == .notConnected || !field.secret
                SettingsRow(label: word(info.fieldKey(field))) {
                    SettingsValue(text: empty ? word("settings.value.empty") : word("settings.value.masked"), tone: empty ? \.inkTertiary : \.inkSecondary)
                }
            }
            if info.hasNote { SettingsBlockNote(text: word(info.noteKey)) }
            if reading.state != .notConnected {
                areas(reading)
                ForEach(info.extras, id: \.id) { extra in
                    SettingsRow(label: word(info.extraKey(extra))) {
                        TextButton(label: word(extra.actionKey), disabled: !canRun(extra, reading)) { run(extra, reading) }
                            .opacity(canRun(extra, reading) ? 1 : SheetValues.disabledOpacity)
                    }
                }
            }
        }
    }

    private var access: String {
        let method = String(localized: String.LocalizationValue(info.access.key))
        return SettingsFormat.text(info.companyOwned ? "settings.access.company" : "settings.access.personal", method)
    }

    private func note(_ note: LinkNote?) -> Text? {
        switch note {
        case .checked(let date): Text(verbatim: SettingsFormat.text("settings.note.checked", SettingsFormat.relative(date)))
        case .unchecked: word("settings.note.unchecked")
        case .signingIn: word("settings.note.signingIn")
        case .failed(let at, let lastOK):
            switch (at, lastOK) {
            case (let at?, let ok?):
                Text(verbatim: SettingsFormat.text("settings.note.failed", SettingsFormat.relative(at), SettingsFormat.day(ok)))
            case (let at?, nil):
                Text(verbatim: SettingsFormat.text("settings.note.failedOnly", SettingsFormat.relative(at)))
            default: nil
            }
        case nil: nil
        }
    }

    @ViewBuilder
    private var progress: some View {
        if started || host.actedOn == info.id, host.busy || host.failure != nil {
            VStack(alignment: .leading, spacing: CGFloat(Design.Spacing.step4)) {
                if host.busy { word("settings.link.connecting").designText(\.inkTertiary, size: Design.TextSize.small) }
                if let failure = host.failure { hintWords(failure).designText(\.signal, size: Design.TextSize.small) }
            }
            .padding(.horizontal, CGFloat(Design.Spacing.step16))
            .padding(.vertical, CGFloat(Design.Spacing.step8))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func notices(_ reading: ServiceReading) -> some View {
        switch reading.state {
        case .failed:
            SettingsBlockNotice(
                kind: .failure,
                title: Text(verbatim: SettingsFormat.text("settings.failed.title", reason(reading.hint))),
                text: word("settings.failed.body")
            ) {
                TextButton(label: word("settings.action.reconnect"), kind: .accent, disabled: host.busy) { perform(reading.step) }
            }
        case .unreadable:
            SettingsBlockNotice(kind: .failure, title: word("settings.unreadable.title"), text: word("settings.unreadable.body")) {
                TextButton(label: word("settings.action.reenter"), disabled: host.busy) { perform(reading.step) }
            }
        case .orphaned:
            SettingsBlockNotice(kind: .warning, title: word("settings.orphaned.title"), text: word("settings.orphaned.body")) {
                TextButton(label: word("text.settings.action.remove"), kind: .signal, disabled: host.busy) { disconnect(reading) }
            }
        default:
            EmptyView()
        }
    }

    private func reason(_ hint: Hint?) -> String {
        guard let hint else { return String(localized: "settings.failed.unknown") }
        var text = String(localized: String.LocalizationValue(hint.text))
        if let status = hint.original?.status { text += " (\(status))" }
        return text
    }

    @ViewBuilder
    private func accounts(_ reading: ServiceReading) -> some View {
        if info.listsAccounts {
            SettingsBlockHead(key: "settings.accounts.head")
            if let offer = host.form, info.providers.contains(offer.provider) {
                SettingsAddForm(host: host, offer: offer)
            } else if reading.inlets.isEmpty {
                SettingsBlockNotice(kind: .info, title: word("settings.accounts.none.title"), text: word("settings.accounts.none.text")) {
                    addAccount(reading, kind: .accent)
                }
            } else {
                ForEach(reading.inlets) { inlet in
                    SettingsRow(label: word(inlet.title), sub: inlet.account.isEmpty ? nil : Text(verbatim: inlet.account)) {
                        ServiceStatus(state: LinkState(inlet.state).service, label: word(LinkState(inlet.state).key))
                        TextButton(label: word("text.settings.action.check"), kind: .plain, disabled: host.busy) {
                            started = true
                            Task { await host.probe(inlet.id) }
                        }
                        ConfirmPill(
                            label: word("text.settings.action.remove"),
                            question: Text(verbatim: SettingsFormat.text("settings.disconnect.ask", String(localized: String.LocalizationValue(inlet.title)))),
                            yes: word("text.settings.action.remove"),
                            no: word("confirm.no"),
                            holdHint: word("settings.hold.remove"),
                            showsProgress: false,
                            onYes: { Task { await host.remove(inlet.id) } }
                        )
                    }
                }
                SettingsRow(label: word("text.settings.action.addAccount")) {
                    addAccount(reading, kind: .neutral)
                }
            }
        }
    }

    private func addAccount(_ reading: ServiceReading, kind: TextButtonKind) -> some View {
        SettingsMenuAction(label: word("text.settings.action.addAccount"), kind: kind) {
            reading.offers.map { offer in
                .row(MenuItem(id: offer.id, label: word(offer.title)) {
                    started = true
                    Task { await host.choose(offer) }
                })
            }
        }
        .opacity(host.busy || reading.offers.isEmpty ? SheetValues.disabledOpacity : 1)
        .allowsHitTesting(!host.busy && !reading.offers.isEmpty)
    }

    @ViewBuilder
    private func areas(_ reading: ServiceReading) -> some View {
        if !reading.areas.isEmpty {
            SettingsBlockHead(key: "settings.sync.head")
            ForEach(reading.areas) { area in
                SettingsRow(label: word(info.areaKey(area.area)), sub: sync(area)) {
                    SettingsMenuChoice(label: word(area.choice.key)) {
                        CadenceChoice.allCases.map { choice in
                            .row(MenuItem(id: choice.rawValue, label: word(choice.key), check: choice == area.choice ? Text(Image(systemName: "checkmark")) : nil) {
                                hub.rules.setCadence(area.inlet, area.capability, choice.cadence)
                                revision += 1
                            })
                        }
                    }
                    TextButton(label: word(area.running ? "settings.link.working" : "settings.sync.now"), disabled: area.running) {
                        Task {
                            await hub.rules.syncNow(area.inlet, area.capability)
                            revision += 1
                        }
                    }
                    .opacity(area.running ? SheetValues.disabledOpacity : 1)
                }
            }
        }
    }

    private func sync(_ area: AreaReading) -> Text {
        if area.running { return word("settings.link.working") }
        guard let last = area.lastSync else { return word("settings.sync.never") }
        return Text(verbatim: SettingsFormat.text("settings.sync.last", SettingsFormat.relative(last)))
    }

    private func canRun(_ extra: ServiceExtra, _ reading: ServiceReading) -> Bool {
        guard case .syncNow(let capability) = extra.action else { return false }
        return reading.inlets.contains { $0.capabilities.contains(capability) }
    }

    private func run(_ extra: ServiceExtra, _ reading: ServiceReading) {
        guard case .syncNow(let capability) = extra.action, let inlet = reading.inlets.first(where: { $0.capabilities.contains(capability) }) else { return }
        Task {
            await hub.rules.syncNow(inlet.id, capability)
            revision += 1
        }
    }

    private func perform(_ step: ServiceStep) {
        started = true
        host.perform(step, for: info.id)
    }

    private func disconnect(_ reading: ServiceReading) {
        Task {
            for inlet in reading.inlets { await host.remove(inlet.id) }
        }
    }
}

struct SettingsAddForm: View {
    @Bindable var host: AppHost
    let offer: Offer

    private var fields: [Field] {
        switch offer.way {
        case .form(let fields), .key(let fields): fields
        case .signIn: []
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CGFloat(Design.Spacing.step8)) {
            ForEach(fields) { field in
                FormInput(labelKey: field.title, secret: field.secret, text: binding(field.id))
            }
            HStack(spacing: CGFloat(Design.Spacing.step8)) {
                TextButton(label: word("settings.signin"), kind: .accent, disabled: host.busy) {
                    Task { await host.add(offer, input: .fields(host.values)) }
                }
                TextButton(label: word("text.common.cancel"), kind: .plain) { host.close() }
            }
            if host.busy { word("settings.link.connecting").designText(\.inkTertiary, size: Design.TextSize.small) }
            if let failure = host.failure { hintWords(failure).designText(\.signal, size: Design.TextSize.small) }
        }
        .padding(.horizontal, CGFloat(Design.Spacing.step16))
        .padding(.vertical, CGFloat(Design.Spacing.step8))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func binding(_ id: String) -> Binding<String> {
        Binding(get: { host.values[id] ?? "" }, set: { host.values[id] = $0 })
    }
}

private struct FormInput: View {
    @Environment(\.design) private var design
    let labelKey: String
    let secret: Bool
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: CGFloat(Design.Spacing.step4)) {
            word(labelKey).designText(\.inkTertiary, size: Design.TextSize.small)
            Group {
                if secret {
                    SecureField(text: $text) { word(labelKey) }
                } else {
                    TextField(text: $text) { word(labelKey) }
                }
            }
            .textFieldStyle(.plain)
            .font(.face(Design.TextSize.body))
            .foregroundStyle(design.color(\.ink))
            .autocorrectionDisabled()
            .frame(height: CGFloat(Design.Spacing.step28))
            .overlay(alignment: .bottom) {
                Rectangle().fill(design.color(\.ink)).frame(height: CGFloat(Design.Size.hairline))
            }
        }
    }
}
