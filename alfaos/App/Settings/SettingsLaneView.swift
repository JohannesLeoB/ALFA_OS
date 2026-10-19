import Hub
import ShellCore
import SwiftUI

struct SettingsLaneView: View {
    let lane: Lane
    @Environment(\.hostLive) private var live
    @Environment(\.appHost) private var host

    var body: some View {
        if live, let host {
            SettingsLaneContent(host: host, lane: lane)
        } else {
            Color.clear.frame(maxHeight: .infinity)
        }
    }
}

private struct SettingsLaneContent: View {
    @Bindable var host: AppHost
    let lane: Lane

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onAppear { host.prepare() }
    }

    @ViewBuilder
    private var content: some View {
        switch host.phase {
        case .idle, .failed:
            Color.clear
        case .ready(let assembly):
            let readings = ServiceReader.readAll(setup: assembly.hub.setup, rules: assembly.hub.rules)
            switch lane {
            case .leading: SettingsGroupsPane(board: SettingsShared.board, readings: readings)
            case .center: SettingsCenterPane(board: SettingsShared.board, readings: readings)
            case .trailing: SettingsStackPane(host: host, board: SettingsShared.board, hub: assembly.hub, readings: readings)
            }
        }
    }
}

struct SettingsStripMarks: View {
    let host: AppHost
    let lane: Lane
    let height: Double

    var body: some View {
        if case .ready(let assembly) = host.phase {
            let readings = ServiceReader.readAll(setup: assembly.hub.setup, rules: assembly.hub.rules)
            let board = SettingsShared.board
            let entries = board.group == .connections
                ? readings.map(\.info.id) + [SettingsSection.keyInventory.rawValue]
                : board.group.sections.map(\.rawValue)
            let failed = Set(readings.filter { $0.state == .failed }.map(\.info.id))
            let marks = board.stripMarks(lane, height: height, entries: entries, failed: failed) { SettingsFace(id: $0, readings: readings).title }
            StripMarks(items: marks.map { mark in
                StripMarkItem(id: mark.id, face: mark.face, help: mark.titleKey.map { word($0) } ?? Text(verbatim: mark.title),
                              selected: mark.selected, dot: mark.dot) { board.run(mark.run) }
            })
        }
    }
}

extension AppearanceChoice {
    var scheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

struct SettingsGroupsPane: View {
    let board: SettingsBoard
    let readings: [ServiceReading]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(SettingsGroup.allCases, id: \.self) { group in
                    let selected = board.group == group
                    let bad = group == .connections ? ServiceReader.badCount(readings) : 0
                    LaneRow(glyph: Icon(rawValue: group.symbol) ?? .system, label: word(group.key), selected: selected,
                            count: bad > 0 ? String(bad) : nil, countTone: selected ? \.lane : \.signal) {
                        board.group = group
                    }
                }
            }
            .padding(CGFloat(Design.Spacing.step8))
        }
        .scrollIndicators(.never)
    }
}

struct SettingsCenterPane: View {
    let board: SettingsBoard
    let readings: [ServiceReading]

    var body: some View {
        if board.group == .connections {
            SettingsTiles(board: board, readings: readings)
        } else {
            SettingsSectionList(board: board)
        }
    }
}

private struct SettingsSectionList: View {
    let board: SettingsBoard
    @AppStorage(SettingsKey.appearance) private var appearance = AppearanceChoice.system.rawValue

    var body: some View {
        let sections = board.group.sections
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                    let selected = board.front == section.rawValue
                    let next = sections.indices.contains(index + 1) ? sections[index + 1] : nil
                    SectionRow(
                        section: section,
                        value: value(of: section),
                        selected: selected,
                        separated: next != nil && !selected && board.front != next?.rawValue,
                        action: { board.open(section.rawValue) })
                }
            }
            .padding(CGFloat(Design.Spacing.step8))
        }
        .scrollIndicators(.never)
    }

    private func value(of section: SettingsSection) -> String? {
        guard section == .appearance else { return nil }
        let choice = AppearanceChoice(rawValue: appearance) ?? .system
        return String(localized: String.LocalizationValue(choice.key))
    }
}

private struct SectionRow: View {
    @Environment(\.design) private var design
    let section: SettingsSection
    let value: String?
    let selected: Bool
    let separated: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: CGFloat(Design.Radius.row))
        let ink = selected ? InkSet.inverse : InkSet.lane
        Button(action: action) {
            MessageRow(fill: selected ? design.color(\.ink) : (hovering ? design.color(\.lane) : Color.clear),
                       ring: hovering && !selected ? design.color(\.lineStrong) : nil, separated: separated) {
                Mark(inverted: selected) { Text(verbatim: SettingsFormat.initial(String(localized: String.LocalizationValue(section.key)))) }
            } content: {
                HStack(spacing: CGFloat(Design.Spacing.step8)) {
                    word(section.key)
                        .lineLimit(1)
                        .font(.face(Design.TextSize.body, weight: Design.Weight.medium))
                        .foregroundStyle(design.color(selected ? \.lane : \.ink))
                    Spacer(minLength: 0)
                    if let value {
                        Text(verbatim: value)
                            .font(.face(Design.TextSize.small))
                            .monospacedDigit()
                            .foregroundStyle(design.color(ink.tertiary))
                    }
                }
                .frame(height: CGFloat(Design.LineHeight.notice))
                word(section.detailKey)
                    .lineLimit(1)
                    .font(.face(Design.TextSize.body))
                    .foregroundStyle(design.color(ink.tertiary))
                    .frame(height: CGFloat(Design.LineHeight.notice), alignment: .leading)
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct SettingsTiles: View {
    let board: SettingsBoard
    let readings: [ServiceReading]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CGFloat(Design.Spacing.step16)) {
                tileGroup("settings.tiles.integrations") {
                    ForEach(readings) { reading in
                        SettingsTile(
                            name: LocalizedStringKey(reading.info.nameKey),
                            initial: SettingsFormat.initial(String(localized: String.LocalizationValue(reading.info.nameKey))),
                            logo: image(reading.info.logo),
                            sub: reading.state.key,
                            bad: reading.state.isBad,
                            selected: board.front == reading.info.id && !board.fanned,
                            action: { board.open(reading.info.id) })
                    }
                }
                tileGroup("settings.tiles.keys") {
                    SettingsTile(
                        name: LocalizedStringKey(SettingsSection.keyInventory.key),
                        initial: SettingsFormat.initial(String(localized: String.LocalizationValue(SettingsSection.keyInventory.key))),
                        logo: nil,
                        sub: SettingsSection.keyInventory.detailKey,
                        bad: false,
                        selected: board.front == SettingsSection.keyInventory.rawValue && !board.fanned,
                        action: { board.open(SettingsSection.keyInventory.rawValue) })
                }
            }
            .padding(.horizontal, CGFloat(Design.Spacing.step16))
            .padding(.top, CGFloat(Design.Spacing.step8))
            .padding(.bottom, CGFloat(Design.Spacing.step16))
        }
        .scrollIndicators(.never)
    }

    private func image(_ logo: ServiceLogo?) -> NSImage? {
        guard let logo, let url = Bundle.main.url(forResource: logo.resource, withExtension: logo.fileExtension) else { return nil }
        return NSImage(contentsOf: url)
    }

    private func tileGroup<Content: View>(_ key: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: CGFloat(Design.Spacing.step8)) {
            word(key)
                .designText(\.inkTertiary, size: Design.TextSize.small)
                .padding(.horizontal, CGFloat(Design.Spacing.step4))
                .frame(height: CGFloat(Design.Spacing.step24), alignment: .bottomLeading)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: CGFloat(Design.Size.settingsTileMinWidth)), spacing: CGFloat(Design.Spacing.step8))],
                spacing: CGFloat(Design.Spacing.step8)) {
                    content()
                }
        }
    }
}
