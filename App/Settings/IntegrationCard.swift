import Assistant
import Design
import Foundation
import Hub
import SwiftUI

struct IntegrationCard: View {
    @Environment(\.appearance) private var appearance
    @Environment(\.narrowCard) private var narrow
    let context: SettingsContext
    let info: IntegrationInfo
    var disconnecting = false
    var endDisconnect: () -> Void = {}
    @State private var started = false
    @State private var held = IntegrationValues.none

    private var flow: AccountFlow { context.flow }

    private var reading: IntegrationReading {
        IntegrationReadEngine.read(info, setup: context.setup, rules: context.rules)
    }

    private var name: String { appearance.string(info.nameKey) }

    var body: some View {
        let reading = reading
        VStack(spacing: 0) {
            IntegrationHero(info: info)
            progress
            SettingsRow(label: appearance.text("settings.row.state"), sub: note(reading.note)) {
                ConnectionStatus(state: reading.state.connection, label: appearance.text(reading.state.key), trailingInset: true)
            }
            notices(reading)
            if disconnecting { disconnectNotice(reading) }
            accounts(reading)
            if reading.state != .notConnected, reading.inlets.contains(where: hasMailbox) {
                SettingsRow(label: appearance.text("settings.privacy.images")) {
                    ToggleSwitch(
                        isOn: Binding(get: { context.state.privacy.loadImages }, set: { value in context.state.updatePrivacy { $0.loadImages = value } }),
                        labelKey: "settings.privacy.images")
                }
            }
            SettingsRow(label: appearance.text("settings.row.access")) {
                SettingsValue(text: Text(verbatim: access))
            }
            if let offer = flow.form, !info.listsAccounts, info.providers.contains(offer.provider) {
                AddEditor(flow: flow, offer: offer)
            } else {
                ForEach(info.fields, id: \.id) { field in
                    if field.id == "model", reading.state != .notConnected, let inlet = reading.lead {
                        modelRow(field, inlet: inlet, reading: reading)
                    } else {
                        let value = value(of: field, reading)
                        SettingsRow(label: appearance.text(info.fieldKey(field))) {
                            SettingsValue(text: value.text, tone: value.tone)
                        }
                    }
                }
            }
            if reading.state != .notConnected {
                if !info.listsAccounts {
                    ForEach(reading.inlets.filter(hasMailbox)) { inlet in
                        MailboxDisplayRow(state: context.state, inlet: inlet)
                        MailboxRangeRow(state: context.state, inbox: context.inbox, inlet: inlet)
                    }
                }
                areas(reading)
                ForEach(info.extras, id: \.id) { extra in
                    SettingsRow(label: appearance.text(info.extraKey(extra))) {
                        TextButton(label: appearance.text(extra.actionKey), disabled: !canRun(extra, reading)) { run(extra, reading) }
                    }
                }
            }
        }
        .task(id: reading.inlets.map(\.id).joined() + reading.state.rawValue) {
            held = IntegrationReadEngine.values(of: reading, keychain: context.keychain)
        }
    }

    private func modelRow(_ field: IntegrationField, inlet: Inlet, reading: IntegrationReading) -> some View {
        let current = ClaudeModelChoice.stored(held.text[field.id])
        return SettingsRow(label: appearance.text(info.fieldKey(field))) {
            ChoiceButton(label: appearance.text(current.key)) {
                ClaudeModelChoice.allCases.map { choice in
                    .row(MenuItem(id: choice.rawValue, label: appearance.text(choice.key),
                                  check: choice == current ? appearance.text(SettingsKeys.menuCheck) : nil) {
                        let slot = KeySlot(inlet: inlet.id, name: field.id)
                        if let id = choice.id { try? context.keychain.put(id, at: slot) } else { try? context.keychain.delete(slot) }
                        held = IntegrationReadEngine.values(of: reading, keychain: context.keychain)
                    })
                }
            }
        }
    }

    private func value(of field: IntegrationField, _ reading: IntegrationReading) -> (text: Text, tone: KeyPath<Colors, ColorValue>) {
        guard reading.state != .notConnected else { return (appearance.text(SettingsKeys.valueEmpty), \.inkTertiary) }
        if field.secret { return (appearance.text("settings.value.masked"), \.inkSecondary) }
        if let text = held.text[field.id] { return (Text(verbatim: text), \.inkSecondary) }
        if let key = field.fallbackKey { return (appearance.text(key), \.inkSecondary) }
        return (appearance.text(SettingsKeys.valueEmpty), \.inkTertiary)
    }

    private var access: String {
        appearance.format(info.companyOwned ? "settings.access.company" : "settings.access.personal", appearance.string(info.access.key))
    }

    private func note(_ note: LinkNote?) -> Text? {
        switch note {
        case .checked(let date): Text(verbatim: appearance.format("settings.note.checked", SettingsDates.relative(date)))
        case .unchecked: appearance.text("settings.note.unchecked")
        case .signingIn: appearance.text("settings.note.signingIn")
        case .failed(let at, let lastOK):
            switch (at, lastOK) {
            case (let at?, let ok?):
                Text(verbatim: appearance.format("settings.note.failed", SettingsDates.relative(at), SettingsDates.day(ok)))
            case (let at?, nil):
                Text(verbatim: appearance.format("settings.note.failedOnly", SettingsDates.relative(at)))
            default: nil
            }
        case nil: nil
        }
    }

    @ViewBuilder
    private var progress: some View {
        if started || flow.actedOn == info.id, flow.busy || flow.failure != nil {
            VStack(alignment: .leading, spacing: CGFloat(Tokens.Spacing.step4)) {
                if flow.busy { appearance.text("settings.link.connecting").designText(\.inkTertiary, size: Tokens.TextSize.small) }
                if let failure = flow.failure { HintText(hint: failure).designText(\.signal, size: Tokens.TextSize.small) }
            }
            .padding(.horizontal, CGFloat(Tokens.Spacing.step16))
            .padding(.vertical, CGFloat(Tokens.Spacing.step8))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func notices(_ reading: IntegrationReading) -> some View {
        switch reading.state {
        case .failed:
            BlockNotice(
                kind: .failure,
                title: Text(verbatim: appearance.format("settings.failed.title", reason(reading.hint))),
                text: appearance.text("settings.failed.body")
            ) {
                TextButton(label: appearance.text("settings.action.reconnect"), kind: .accent, disabled: flow.busy) { perform(reading.step) }
            }
        case .unreadable:
            BlockNotice(kind: .failure, title: appearance.text("settings.unreadable.title"), text: appearance.text("settings.unreadable.body")) {
                TextButton(label: appearance.text("settings.action.reenter"), disabled: flow.busy) { perform(reading.step) }
            }
        case .orphaned:
            BlockNotice(kind: .warning, title: appearance.text("settings.orphaned.title"), text: appearance.text("settings.orphaned.body")) {
                TextButton(label: appearance.text("text.settings.action.remove"), kind: .signal, disabled: flow.busy) {
                    Task { await flow.remove(reading.inlets.map(\.id)) }
                }
            }
        default:
            EmptyView()
        }
    }

    private func disconnectNotice(_ reading: IntegrationReading) -> some View {
        let target = reading.leadAddress ?? name
        let removed = reading.leadAddress != nil ? reading.lead.map { [$0.id] } ?? [] : reading.inlets.map(\.id)
        return BlockNotice(
            kind: .warning,
            title: Text(verbatim: appearance.format("settings.disconnect.ask", target)),
            text: Text(verbatim: appearance.format("settings.disconnect.text", target))
        ) {
            TextButton(label: appearance.text("settings.action.disconnect"), kind: .signal, disabled: flow.busy) {
                endDisconnect()
                Task { await flow.remove(removed) }
            }
            TextButton(label: appearance.text("text.common.cancel"), kind: .plain) { endDisconnect() }
        }
    }

    private func reason(_ hint: Hint?) -> String {
        guard let hint else { return appearance.string(SettingsKeys.failedUnknown) }
        var text = appearance.string(hint.text)
        if let status = hint.original?.status { text += " (\(status))" }
        return text
    }

    @ViewBuilder
    private func accounts(_ reading: IntegrationReading) -> some View {
        if info.listsAccounts {
            BlockHead(key: "settings.accounts.head")
            if let offer = flow.form, info.providers.contains(offer.provider) {
                AddEditor(flow: flow, offer: offer)
            } else if reading.inlets.isEmpty {
                BlockNotice(kind: .warning, title: appearance.text("settings.accounts.none.title")) {
                    addAccount(reading, kind: .accent)
                }
            } else {
                ForEach(reading.inlets) { inlet in
                    SettingsRow(label: inlet.account.isEmpty ? appearance.text(inlet.title) : Text(verbatim: inlet.account),
                                sub: inlet.account.isEmpty ? nil : appearance.text(inlet.title),
                                line: !hasMailbox(inlet)) {
                        ConnectionStatus(state: LinkState(inlet.state).connection, label: appearance.text(LinkState(inlet.state).key))
                        TextButton(label: appearance.text("text.settings.action.check"), kind: .plain, disabled: flow.busy) {
                            started = true
                            Task { await flow.probe(inlet.id) }
                        }
                        ConfirmPill(
                            label: appearance.text("text.settings.action.remove"),
                            question: Text(verbatim: appearance.format("settings.disconnect.ask", inlet.account.isEmpty ? appearance.string(inlet.title) : inlet.account)),
                            yes: appearance.text("text.settings.action.remove"),
                            no: appearance.text("confirm.no"),
                            holdHint: appearance.text("settings.hold.remove"),
                            showsProgress: false,
                            onYes: { Task { await flow.remove([inlet.id]) } }
                        )
                        .rowPill()
                    }
                    if hasMailbox(inlet) {
                        MailboxDisplayRow(state: context.state, inlet: inlet)
                        MailboxRangeRow(state: context.state, inbox: context.inbox, inlet: inlet)
                    }
                }
                SettingsRow(label: appearance.text("text.settings.action.addAccount")) {
                    addAccount(reading, kind: .neutral)
                }
            }
        }
    }

    private func hasMailbox(_ inlet: Inlet) -> Bool {
        inlet.capabilities.contains(.mail)
    }

    private func addAccount(_ reading: IntegrationReading, kind: TextButtonKind) -> some View {
        TextMenuButton(label: appearance.text("text.settings.action.addAccount"), kind: kind, disabled: flow.busy || reading.offers.isEmpty) {
            reading.offers.map { offer in
                .row(MenuItem(id: offer.id, label: appearance.text(offer.title)) {
                    started = true
                    Task { await flow.choose(offer) }
                })
            }
        }
    }

    @ViewBuilder
    private func areas(_ reading: IntegrationReading) -> some View {
        if !reading.areas.isEmpty {
            BlockHead(key: "settings.sync.head")
            ForEach(reading.areas) { area in
                SettingsRow(label: areaLabel(area, shared: reading.inlets.count > 1), sub: sync(area)) {
                    ChoiceButton(label: appearance.text(area.choice.key)) {
                        var entries: [MenuEntry] = CadenceChoice.allCases.map { choice in
                            .row(MenuItem(id: choice.rawValue, label: appearance.text(choice.key),
                                          check: choice == area.choice ? appearance.text(SettingsKeys.menuCheck) : nil) {
                                context.rules.setCadence(area.inlet, area.capability, choice.cadence)
                            })
                        }
                        if narrow {
                            entries.append(.separator(id: "sync.separator"))
                            entries.append(.row(MenuItem(id: "sync.now", label: appearance.text(area.running ? "settings.link.working" : "settings.sync.now")) {
                                syncNow(area)
                            }))
                        }
                        return entries
                    }
                    if !narrow {
                        TextButton(label: appearance.text(area.running ? "settings.link.working" : "settings.sync.now"), disabled: area.running) {
                            syncNow(area)
                        }
                    }
                }
            }
        }
    }

    private func areaLabel(_ area: AreaReading, shared: Bool) -> Text {
        let name = appearance.string(info.areaKey(area.area))
        guard shared, !area.account.isEmpty else { return Text(verbatim: name) }
        return Text(verbatim: name + " · " + area.account)
    }

    private func syncNow(_ area: AreaReading) {
        guard !area.running else { return }
        Task { _ = await context.syncNow(area.inlet, area.capability) }
    }

    private func sync(_ area: AreaReading) -> Text {
        if area.running { return appearance.text("settings.link.working") }
        guard let last = area.lastSync else { return appearance.text("settings.sync.never") }
        return Text(verbatim: appearance.format("settings.sync.last", SettingsDates.relative(last)))
    }

    private func canRun(_ extra: IntegrationExtra, _ reading: IntegrationReading) -> Bool {
        reading.inlets.contains { $0.capabilities.contains(extra.capability) }
    }

    private func run(_ extra: IntegrationExtra, _ reading: IntegrationReading) {
        guard let inlet = reading.inlets.first(where: { $0.capabilities.contains(extra.capability) }) else { return }
        Task {
            if await context.syncNow(inlet.id, extra.capability) { context.state.notify("settings.toast.driveSynced") }
        }
    }

    private func perform(_ step: IntegrationStep) {
        started = true
        flow.perform(step, for: info.id)
    }
}

enum SettingsDates {
    static func relative(_ date: Date, now: Date = Date()) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "de")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: now)
    }

    static func day(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de")
        formatter.setLocalizedDateFormatFromTemplate("dMMM")
        return formatter.string(from: date)
    }
}

struct BlockNotice<Actions: View>: View {
    let kind: NoticeKind
    let title: Text
    var text: Text?
    @ViewBuilder let actions: Actions

    var body: some View {
        Notice(kind: kind, title: title, text: text) {
            Glyph(kind == .success ? .check : .alert)
        } actions: {
            actions
        }
        .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
        .padding(.vertical, CGFloat(Tokens.Spacing.step4))
    }
}

struct AddEditor: View {
    @Environment(\.appearance) private var appearance
    @Bindable var flow: AccountFlow
    let offer: Offer

    private var fields: [Field] {
        switch offer.way {
        case .form(let fields), .key(let fields): fields
        case .signIn: []
        }
    }

    private var keyed: Bool {
        if case .key = offer.way { true } else { false }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CGFloat(Tokens.Spacing.step8)) {
            ForEach(fields) { field in
                VStack(alignment: .leading, spacing: CGFloat(Tokens.Spacing.step4)) {
                    appearance.text(field.title).designText(\.inkTertiary, size: Tokens.TextSize.small)
                    InputField(text: binding(field.id), placeholder: nil, labelKey: field.title, secret: field.secret)
                }
            }
            HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
                TextButton(label: appearance.text(keyed ? "settings.action.connect" : "settings.signin"), kind: .accent, disabled: flow.busy) {
                    Task { await flow.add(offer, input: .fields(flow.values)) }
                }
                TextButton(label: appearance.text("text.common.cancel"), kind: .plain) { flow.close() }
            }
            if flow.busy { appearance.text("settings.link.connecting").designText(\.inkTertiary, size: Tokens.TextSize.small) }
            if let failure = flow.failure { HintText(hint: failure).designText(\.signal, size: Tokens.TextSize.small) }
        }
        .padding(.horizontal, CGFloat(Tokens.Spacing.step16))
        .padding(.vertical, CGFloat(Tokens.Spacing.step8))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func binding(_ id: String) -> Binding<String> {
        Binding(get: { flow.values[id] ?? "" }, set: { flow.values[id] = $0 })
    }
}

struct HintText: View {
    @Environment(\.appearance) private var appearance
    let hint: Hint

    var body: some View {
        VStack(alignment: .leading) {
            appearance.text(hint.text)
            if let detail = hint.detail { Text(verbatim: detail) }
        }
    }
}
