import Design
import Hub
import Shell
import SwiftUI

@MainActor
struct SettingsPane: Pane {
    let context: SettingsContext

    var stackEmpty: Bool { context.state.cards.isEmpty }

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
            conversation: assembly.conversation, tiles: TileFocus()))
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
                if context.state.group == .connections { IntegrationList(context: context) } else { SectionList(state: context.state) }
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
                        context.state.group = group
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
    let state: SettingsState

    var body: some View {
        let sections = state.group.sections
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                    let selected = state.front == section.rawValue
                    let next = sections.indices.contains(index + 1) ? sections[index + 1] : nil
                    SectionRow(
                        section: section,
                        value: value(of: section),
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
        SettingsFace(id: id, readings: readings, appearance: appearance)
    }

    private func items(readings: [IntegrationReading], failed: Set<String>) -> [StripMarkItem] {
        switch lane {
        case .leading:
            return SettingsGroup.allCases.map { group in
                StripMarkItem(id: "group." + group.rawValue, face: .glyph(Icon(rawValue: group.symbol) ?? .system),
                              help: appearance.text(group.key), selected: state.group == group, dot: false) { state.group = group }
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
            return state.cards.map { id in
                let item = face(id, readings)
                return StripMarkItem(id: "card." + id, face: .text(item.mark), help: Text(verbatim: item.title), selected: false,
                                     dot: false) { state.bring(id) }
            }
        }
    }
}
