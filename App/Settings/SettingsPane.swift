import Assistant
import Design
import Google
import Hub
import Mail
import Shell
import SwiftUI

@MainActor
struct SettingsPane: Pane {
    let context: SettingsContext

    var badge: Int { IntegrationReadEngine.failedCount(context.readings) }

    func ownsHead(_ lane: LaneKind) -> Bool { lane == .trailing }

    func title(_ lane: LaneKind) -> PaneTitle? {
        guard lane == .center else { return nil }
        let state = context.state
        return .key(state.group == .connections ? (context.tiles.group ?? .integrations).key : state.group.key)
    }

    func name(_ lane: LaneKind) -> PaneTitle? {
        lane == .center ? .key(context.state.group.key) : nil
    }

    func hidesTitle(_ lane: LaneKind) -> Bool { lane == .leading }

    func marks(_ lane: LaneKind, height: Double) -> AnyView? {
        AnyView(SettingsMarkList(context: context, lane: lane, height: height))
    }

    func content(_ lane: LaneKind) -> AnyView {
        AnyView(SettingsLane(context: context, lane: lane))
    }

    var opened: Int { context.state.opened }

    var toast: AnyView? { AnyView(SettingsToast(state: context.state)) }
}

extension SettingsPane {
    static func make(assembly: Assembly, desk: DeskState) -> SettingsPane {
        let inbox = assembly.inbox
        let flow = AccountFlow(setup: assembly.connections.setup, added: { await inbox.selectAccount($0) })
        return SettingsPane(context: SettingsContext(
            state: assembly.settings, catalog: assembly.catalog, setup: assembly.connections.setup, rules: assembly.connections.rules,
            keychain: assembly.keychain, flow: flow, privacy: AssistantPrivacy(store: assembly.privacyStore), inbox: inbox, desk: desk,
            conversation: assembly.conversation, tiles: TileFocus(), access: assembly.connections.access,
            roots: DriveRootStore(settings: assembly.settingStore), clearCache: { assembly.reshelve() }))
    }
}

struct SettingsLane: View {
    let context: SettingsContext
    let lane: LaneKind

    var body: some View {
        Group {
            switch lane {
            case .leading: GroupList(context: context)
            case .center:
                if context.state.group == .connections { IntegrationList(context: context) } else { SectionList(context: context) }
            case .trailing: SettingsStack(context: context)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct GroupList: View {
    @Environment(\.appearance) private var appearance
    let context: SettingsContext

    var body: some View {
        let bad = IntegrationReadEngine.badCount(context.readings)
        ScrollView {
            VStack(spacing: 0) {
                ForEach(SettingsGroup.allCases, id: \.self) { group in
                    let selected = context.state.group == group
                    let count = group == .connections ? bad : 0
                    LaneRow(glyph: Icon(rawValue: group.symbol) ?? .system, label: appearance.text(group.key), selected: selected,
                            count: count > 0 ? String(count) : nil, countTone: selected ? \.lane : \.signal) {
                        context.state.select(group)
                    }
                }
            }
            .padding(CGFloat(Tokens.Spacing.step8))
        }
        .scrollIndicators(.never)
    }
}

struct SectionList: View {
    @Environment(\.appearance) private var appearance
    let context: SettingsContext

    private var state: SettingsState { context.state }

    var body: some View {
        let sections = state.group == .me ? state.group.sections.filter { $0 != .identity } : state.group.sections
        ScrollView {
            VStack(spacing: 0) {
                if state.group == .me {
                    ProfileTile(
                        profile: state.profile,
                        addresses: context.readings.flatMap(\.inlets).filter { $0.capabilities.contains(.mail) }.map(\.account).filter { !$0.isEmpty },
                        selected: state.front == SettingsSection.identity.rawValue,
                        action: { state.open(SettingsSection.identity.rawValue) })
                        .padding(.bottom, CGFloat(Tokens.Spacing.step8))
                }
                ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                    let selected = state.front == section.rawValue
                    let next = sections.indices.contains(index + 1) ? sections[index + 1] : nil
                    SectionRow(
                        section: section,
                        value: value(of: section),
                        detailKey: state.detailKey(of: section),
                        selected: selected,
                        separated: next != nil && !selected && state.front != next?.rawValue,
                        action: { state.open(section.rawValue) })
                }
            }
            .padding(CGFloat(Tokens.Spacing.step8))
        }
        .scrollIndicators(.never)
    }

    private func value(of section: SettingsSection) -> String? {
        section == .appearance ? appearance.string(state.appearance.key) : nil
    }
}

struct SettingsMarkList: View {
    @Environment(\.appearance) private var appearance
    let context: SettingsContext
    let lane: LaneKind
    let height: Double

    private var state: SettingsState { context.state }

    var body: some View {
        let readings = context.readings
        let failed = Set(readings.filter { $0.state == .failed }.map(\.info.id))
        StripMarks(items: items(readings: readings, failed: failed))
    }

    private func face(_ id: String, _ readings: [IntegrationReading]) -> SettingsFace {
        SettingsFace(id: id, readings: readings, appearance: appearance, state: state)
    }

    private func items(readings: [IntegrationReading], failed: Set<String>) -> [StripMarkItem] {
        switch lane {
        case .leading:
            return SettingsGroup.allCases.map { group in
                StripMarkItem(id: "group." + group.rawValue, face: .glyph(Icon(rawValue: group.symbol) ?? .system),
                              help: appearance.text(group.key), selected: state.group == group, dot: false) { state.select(group) }
            }
        case .center:
            let entries = state.group == .connections
                ? readings.map(\.info.id) + [SettingsSection.keyInventory.rawValue]
                : state.group.sections.map(\.rawValue)
            let room = max(1, Int((height - Tokens.Size.stripReserveTop - Tokens.Size.stripReserveBottom) / Tokens.Size.rowHeight))
            return entries.prefix(room).map { id in
                let item = face(id, readings)
                return StripMarkItem(id: "entry." + id, face: .text(item.mark), help: Text(verbatim: item.title), selected: state.front == id,
                                     dot: failed.contains(id)) { state.open(id) }
            }
        case .trailing:
            return state.front.map { id in
                let item = face(id, readings)
                return [StripMarkItem(id: "card." + id, face: .text(item.mark), help: Text(verbatim: item.title), selected: false,
                                      dot: false) { state.open(id) }]
            } ?? []
        }
    }
}

@MainActor
struct SettingsContext {
    let state: SettingsState
    let catalog: IntegrationCatalogStore
    let setup: any SetupPort
    let rules: any RulesPort
    let keychain: any KeychainPort
    let flow: AccountFlow
    let privacy: AssistantPrivacy
    let inbox: InboxState
    let desk: DeskState
    let conversation: ChatState
    let tiles: TileFocus
    let access: any AccessPort
    let roots: DriveRootStore
    let clearCache: () -> Void

    var readings: [IntegrationReading] { IntegrationReadEngine.readAll(catalog, setup: setup, rules: rules) }

    func syncNow(_ inlet: Inlet.ID, _ capability: Capability) async -> SyncReport.Result {
        await rules.syncNow(inlet, capability).result
    }
}

enum SettingsKeys {
    static let failedUnknown = "settings.failed.unknown"
    static let valueEmpty = "settings.value.empty"
    static let menuCheck = "settings.menu.check"
}

struct SettingsFace: Identifiable {
    let id: String
    let title: String
    let meta: String
    let mark: String
    let detail: String
    let preview: String

    @MainActor
    init(id: String, readings: [IntegrationReading], appearance: Appearance, state: SettingsState) {
        self.id = id
        if let reading = readings.first(where: { $0.info.id == id }) {
            let name = appearance.string(reading.info.nameKey)
            title = name
            meta = appearance.string(reading.state.key)
            mark = String(name.prefix(1))
            detail = appearance.string(reading.info.useKey)
            preview = meta
        } else if let section = SettingsSection(rawValue: id) {
            let name = appearance.string(section.key)
            title = name
            meta = state.detailKey(of: section).map { appearance.string($0) } ?? ""
            mark = String(name.prefix(1))
            detail = meta
            preview = ""
        } else {
            title = id
            meta = ""
            mark = String(id.prefix(1))
            detail = ""
            preview = ""
        }
    }
}

struct SettingsToast: View {
    @Environment(\.appearance) private var appearance
    let state: SettingsState

    var body: some View {
        if let key = state.toast {
            ToastView(message: state.toastName.map { Text(verbatim: appearance.format(key, $0)) } ?? appearance.text(key),
                      undoLabel: state.toastRetry == nil ? nil : appearance.text("settings.toast.retry"),
                      onUndo: state.toastRetry.map { retry in { state.dismissToast(); retry() } },
                      failed: state.toastFailed,
                      onDismiss: { state.dismissToast() })
                .id(state.toastSerial)
        }
    }
}

struct SectionRow: View {
    @Environment(\.appearance) private var appearance
    let section: SettingsSection
    let value: String?
    let detailKey: String?
    let selected: Bool
    let separated: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.row))
        let ink = InkSet.of(selected)
        Button(action: action) {
            MessageRow(fill: selected ? appearance.color(\.inverse) : (hovering ? appearance.color(\.lane) : Color.clear),
                       ring: hovering && !selected ? appearance.color(\.lineStrong) : nil, separated: separated) {
                Mark(inverted: selected) { Text(verbatim: String(appearance.string(section.key).prefix(1))) }
            } content: {
                HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
                    appearance.text(section.key)
                        .lineLimit(1)
                        .font(.face(Tokens.TextSize.body, weight: Tokens.Weight.medium))
                        .foregroundStyle(appearance.color(selected ? \.onInverse : \.ink))
                    Spacer(minLength: 0)
                    if let value {
                        Text(verbatim: value)
                            .font(.face(Tokens.TextSize.small))
                            .monospacedDigit()
                            .foregroundStyle(appearance.color(ink.tertiary))
                    }
                }
                .frame(height: CGFloat(Tokens.LineHeight.notice))
                if let detailKey {
                    appearance.text(detailKey)
                        .lineLimit(1)
                        .font(.face(Tokens.TextSize.body))
                        .foregroundStyle(appearance.color(ink.tertiary))
                        .frame(height: CGFloat(Tokens.LineHeight.notice), alignment: .leading)
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct SettingsCommandHead: View {
    @Environment(\.appearance) private var appearance
    let context: SettingsContext
    let readings: [IntegrationReading]
    let width: Double
    @Binding var disconnecting: String?

    private var state: SettingsState { context.state }

    private var reading: IntegrationReading? {
        state.front.flatMap { id in readings.first { $0.info.id == id } }
    }

    private var openLanes: Int {
        context.desk.widths.all.filter { $0 > context.desk.measure.laneFolded }.count
    }

    var body: some View {
        let reading = reading
        var main: [CommandSlot<SettingsCommand>] = []
        if let reading {
            if !reading.info.listsAccounts {
                main.append(CommandSlot(id: "connect", action: .connect, off: reading.state == .connecting))
            }
            if reading.state.canDisconnect {
                main.append(CommandSlot(id: "disconnect", action: .disconnect, signal: true))
            }
        }
        let fold = openLanes > 1 ? [CommandSlot<SettingsCommand>(id: "fold", action: .fold)] : []
        let plan = CommandBarEngine.plan(main: main, tail: [], fan: [], fold: fold, staticMore: false, width: width - Tokens.Size.edge)
        return CommandHead(plan: plan, moreHelp: appearance.string("settings.action.more"), glyph: glyph, help: help, perform: perform, more: more) {
            EmptyView()
        }
    }

    private func glyph(_ command: SettingsCommand) -> Icon? {
        switch command {
        case .connect: .link
        case .disconnect: .close
        case .fold: .minus
        }
    }

    private func help(_ command: SettingsCommand) -> String {
        switch command {
        case .connect: appearance.string(reading?.asksReconnect == true ? "settings.action.reconnect" : "settings.action.connect")
        case .disconnect: appearance.string("settings.action.disconnect")
        case .fold: appearance.string("settings.action.foldColumn")
        }
    }

    private func perform(_ command: SettingsCommand) {
        switch command {
        case .connect: if let reading { context.flow.perform(reading.step, for: reading.info.id) }
        case .disconnect: disconnecting = reading?.info.id
        case .fold: context.desk.toggleFold(.trailing)
        }
    }

    private func more(_ commands: [SettingsCommand]) -> [MenuEntry] {
        commands.enumerated().map { index, command in
            .row(MenuItem(id: String(index), label: Text(verbatim: help(command))) { perform(command) })
        }
    }
}

enum SettingsCommand: Equatable, Sendable {
    case connect
    case disconnect
    case fold
}

struct SettingsStack: View {
    @Environment(\.appearance) private var appearance
    let context: SettingsContext
    @State private var disconnecting: String?

    private var state: SettingsState { context.state }

    var body: some View {
        let readings = context.readings
        GeometryReader { proxy in
            VStack(spacing: 0) {
                SettingsCommandHead(context: context, readings: readings, width: proxy.size.width, disconnecting: $disconnecting)
                if let front = state.front {
                    ScrollView {
                        SettingsDetail(context: context, id: front, disconnecting: disconnecting == front, endDisconnect: { disconnecting = nil })
                            .padding(.top, CGFloat(Tokens.Spacing.step4))
                            .padding(.bottom, CGFloat(Tokens.Spacing.step8))
                    }
                    .mask { CardContentMask() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(appearance.color(\.lane))
                    .environment(\.narrowCard, proxy.size.width < Tokens.Size.breakpointNarrowCard)
                } else {
                    RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.card))
                        .fill(appearance.color(\.lane))
                        .overlay {
                            RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.card))
                                .strokeBorder(appearance.color(\.line), lineWidth: CGFloat(Tokens.Size.hairline))
                        }
                }
            }
        }
        .onChange(of: state.front) { disconnecting = nil }
    }
}

private struct CardContentMask: View {
    var body: some View {
        let inset = CGFloat(Tokens.Spacing.step8)
        let radius = CGFloat(Tokens.Radius.row)
        HStack(spacing: 0) {
            Rectangle().frame(width: inset)
            UnevenRoundedRectangle(topLeadingRadius: radius, topTrailingRadius: radius)
            Rectangle().frame(width: inset)
        }
    }
}
