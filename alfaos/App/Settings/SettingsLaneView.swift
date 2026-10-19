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
            VStack(spacing: CGFloat(Design.Spacing.step8)) {
                ForEach(marks) { mark in
                    StripMarkButton(glyph: mark.glyph, text: mark.text, help: mark.titleKey.map { word($0) } ?? Text(verbatim: mark.title),
                                    selected: mark.selected, dot: mark.dot) { board.run(mark.run) }
                }
            }
            .padding(.vertical, CGFloat(Design.Spacing.step8))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

extension SettingsStripMark {
    var glyph: Icon? {
        if case .glyph(let icon) = face { icon } else { nil }
    }

    var text: String {
        if case .text(let value) = face { value } else { "" }
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
                    GroupRow(
                        group: group,
                        selected: board.group == group,
                        bad: group == .connections ? ServiceReader.badCount(readings) : 0,
                        action: { board.group = group })
                }
            }
            .padding(CGFloat(Design.Spacing.step8))
        }
        .scrollIndicators(.never)
    }
}

private struct GroupRow: View {
    @Environment(\.design) private var design
    let group: SettingsGroup
    let selected: Bool
    let bad: Int
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: CGFloat(Design.Radius.row))
        Button(action: action) {
            HStack(spacing: CGFloat(Design.Spacing.step20)) {
                Mark(inverted: selected, tone: selected ? \.lane : \.inkTertiary) {
                    Glyph(Icon(rawValue: group.symbol) ?? .system)
                }
                word(group.key)
                    .lineLimit(1)
                    .font(.face(Design.TextSize.body, weight: selected ? Design.Weight.medium : Design.Weight.regular))
                    .foregroundStyle(design.color(selected ? \.lane : \.ink))
                Spacer(minLength: 0)
                if bad > 0 { Counter(value: String(bad), tone: selected ? \.lane : \.signal) }
            }
            .padding(.horizontal, CGFloat(Design.Spacing.step8))
            .frame(height: CGFloat(Design.Size.rowHeight))
            .background(shape.fill(selected ? design.color(\.ink) : Color.clear))
            .ring(shape, hovering && !selected ? design.color(\.lineStrong) : nil)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityAddTraits(selected ? .isSelected : [])
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
            HStack(alignment: .top, spacing: CGFloat(Design.Spacing.step20)) {
                Mark(inverted: selected) { Text(verbatim: SettingsFormat.initial(String(localized: String.LocalizationValue(section.key)))) }
                VStack(alignment: .leading, spacing: 0) {
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
                .padding(.top, CGFloat(Design.Spacing.step4))
            }
            .padding(.vertical, CGFloat(Design.Spacing.step12))
            .padding(.horizontal, CGFloat(Design.Spacing.step8))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(selected ? design.color(\.ink) : (hovering ? design.color(\.lane) : Color.clear)))
            .ring(shape, hovering && !selected ? design.color(\.lineStrong) : nil)
            .overlay(alignment: .bottom) {
                if separated {
                    Rectangle()
                        .fill(design.color(\.line))
                        .frame(height: CGFloat(Design.Size.hairline))
                        .padding(.leading, CGFloat(Design.Spacing.step56))
                        .padding(.trailing, CGFloat(Design.Spacing.step8))
                }
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
                        ServiceTile(
                            name: LocalizedStringKey(reading.info.nameKey),
                            initial: SettingsFormat.initial(String(localized: String.LocalizationValue(reading.info.nameKey))),
                            logo: reading.info.logo,
                            sub: reading.state.key,
                            bad: reading.state.isBad,
                            selected: board.front == reading.info.id && !board.fanned,
                            action: { board.open(reading.info.id) })
                    }
                }
                tileGroup("settings.tiles.keys") {
                    ServiceTile(
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

private struct ServiceTile: View {
    @Environment(\.design) private var design
    @Environment(\.accessibilityReduceMotion) private var reduced
    let name: LocalizedStringKey
    let initial: String
    let logo: ServiceLogo?
    let sub: String
    let bad: Bool
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: CGFloat(Design.Radius.row))
        let lift = hovering && !selected ? CGFloat(Design.Size.tileHoverLift) : 0
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                badge
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: CGFloat(Design.Spacing.step4) / 2) {
                    Text(name)
                        .lineLimit(1)
                        .font(.face(Design.TextSize.body, weight: Design.Weight.medium))
                        .foregroundStyle(design.color(selected ? \.lane : \.ink))
                    Text(LocalizedStringKey(sub))
                        .lineLimit(1)
                        .font(.face(Design.TextSize.small))
                        .foregroundStyle(design.color(selected ? \.lane : (bad ? \.signal : \.inkTertiary)))
                }
            }
            .padding(CGFloat(Design.Spacing.step12))
            .frame(maxWidth: .infinity, minHeight: CGFloat(SheetValues.settingsTileHeight), maxHeight: CGFloat(SheetValues.settingsTileHeight), alignment: .topLeading)
            .background(shape.fill(selected ? design.color(\.ink) : design.color(\.well)))
            .ring(shape, hovering && !selected ? design.color(\.inkTertiary) : nil)
            .offset(y: -lift)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(ComponentMotion(reduced: reduced).curve(Design.Duration.hover), value: hovering)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var badge: some View {
        let side = CGFloat(Design.Size.symbolSize)
        return ZStack {
            if let image = logoImage {
                Circle().fill(Color(.sRGB, red: DesignColors.light.lane.red, green: DesignColors.light.lane.green, blue: DesignColors.light.lane.blue, opacity: DesignColors.light.lane.alpha))
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: CGFloat(Design.Size.tileLogoSize), height: CGFloat(Design.Size.tileLogoSize))
            } else {
                Text(verbatim: initial)
                    .font(.face(Design.TextSize.small, weight: Design.Weight.medium))
                    .foregroundStyle(design.color(selected ? \.lane : \.ink))
            }
        }
        .frame(width: side, height: side)
        .clipShape(Circle())
        .ring(Circle(), design.color(selected ? \.lane : \.lineStrong))
    }

    private var logoImage: NSImage? {
        guard let logo, let url = Bundle.main.url(forResource: logo.resource, withExtension: logo.fileExtension) else { return nil }
        return NSImage(contentsOf: url)
    }
}
