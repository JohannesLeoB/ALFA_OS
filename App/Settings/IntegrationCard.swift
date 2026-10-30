import Assistant
import Core
import Design
import Foundation
import Hub
import Mail
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
                ConnectionStatus(state: reading.state.connection, label: appearance.text(reading.state.key))
            }
            notices(reading)
            if disconnecting { disconnectNotice(reading) }
            if info.listsAccounts { AccountBlock(context: context, info: info, reading: reading, started: $started) }
            if reading.state != .notConnected, reading.inlets.contains(where: AccountBlock.hasMailbox) {
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
                AddEditor(flow: flow, offers: reading.offers, offer: offer)
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
            if info.id == "claude", reading.state != .notConnected, let usage = context.conversation.usage {
                UsageBlock(usage: usage)
            }
            if reading.state != .notConnected {
                if !info.listsAccounts {
                    ForEach(reading.inlets.filter(AccountBlock.hasMailbox)) { inlet in
                        MailboxNameRow(state: context.state, inlet: inlet)
                        MailboxDisplayRow(state: context.state, inlet: inlet)
                        MailboxRangeRow(state: context.state, inbox: context.inbox, inlet: inlet)
                        MailboxServerCopyRow(state: context.state, inbox: context.inbox, inlet: inlet)
                        SignatureBlock(state: context.state, inlet: inlet)
                    }
                }
                areas(reading)
                ForEach(info.extras, id: \.id) { extra in
                    extraRows(extra, reading)
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
        if started || flow.actedOn == info.id, flow.form == nil {
            if flow.busy {
                HStack(spacing: CGFloat(Tokens.Spacing.step12)) {
                    appearance.text("settings.link.connecting").designText(\.inkTertiary, size: Tokens.TextSize.small)
                    if flow.canCancel {
                        TextButton(label: appearance.text("text.common.cancel"), kind: .plain) { flow.cancel() }
                    }
                }
                .padding(.horizontal, CGFloat(Tokens.Spacing.step16))
                .padding(.vertical, CGFloat(Tokens.Spacing.step8))
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if let failure = flow.failure {
                BlockNotice(kind: .failure, title: Text(verbatim: appearance.format("settings.failed.title", failure.line(appearance))))
            } else if let checked = flow.checked, reading.inlets.contains(where: { $0.id == checked }) {
                BlockNotice(kind: .success, title: appearance.text("settings.check.ok.title"))
            }
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
                    started = true
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
            text: Text(verbatim: AccountBlock.waiting(removed, context: context, appearance: appearance).map { appearance.format("settings.disconnect.text", target) + " " + $0 }
                ?? appearance.format("settings.disconnect.text", target))
        ) {
            TextButton(label: appearance.text("settings.action.disconnect"), kind: .signal, disabled: flow.busy) {
                endDisconnect()
                started = true
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
    private func areas(_ reading: IntegrationReading) -> some View {
        if !reading.areas.isEmpty {
            BlockHead(key: "settings.sync.head")
            ForEach(reading.areas) { area in
                SettingsRow(label: areaLabel(area, shared: reading.inlets.count > 1), sub: sync(area, reading)) {
                    ChoiceButton(label: appearance.text(area.choice.key)) {
                        var entries: [MenuEntry] = CadenceChoice.offered(for: area.capability).map { choice in
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
        return Text(verbatim: appearance.format("settings.area.account", name, area.account))
    }

    private func syncNow(_ area: AreaReading) {
        guard !area.running else { return }
        Task {
            if await !context.syncNow(area.inlet, area.capability) { context.state.notify("settings.toast.syncFailed") }
        }
    }

    private func sync(_ area: AreaReading, _ reading: IntegrationReading) -> Text {
        if area.running { return appearance.text("settings.link.working") }
        guard let last = area.lastSync else { return appearance.text("settings.sync.never") }
        let when = SettingsDates.relative(last)
        switch reading.state {
        case .failed: return Text(verbatim: appearance.format("settings.sync.lastFailed", reason(reading.hint), when))
        case .connected: return Text(verbatim: appearance.format("settings.sync.lastOK", when))
        default: return Text(verbatim: appearance.format("settings.sync.last", when))
        }
    }

    @ViewBuilder
    private func extraRows(_ extra: IntegrationExtra, _ reading: IntegrationReading) -> some View {
        switch extra.kind {
        case .projectRoot:
            if let inlet = reading.inlets.first(where: { extra.capability.map($0.capabilities.contains) ?? false }) {
                ProjectRootRows(context: context, info: info, extra: extra, inlet: inlet)
            }
        case .clear:
            SettingsRow(label: appearance.text(info.extraKey(extra))) {
                TextButton(label: appearance.text(extra.actionKey)) {
                    context.clearCache()
                    context.state.notify("settings.toast.cacheCleared")
                }
            }
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
        formatter.locale = .current
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: now)
    }

    static func day(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
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

extension BlockNotice where Actions == EmptyView {
    init(kind: NoticeKind, title: Text, text: Text? = nil) {
        self.init(kind: kind, title: title, text: text) { EmptyView() }
    }
}

extension Hint {
    func line(_ appearance: Appearance) -> String {
        [appearance.string(text), detail].compactMap { $0 }.joined(separator: " ")
    }
}
