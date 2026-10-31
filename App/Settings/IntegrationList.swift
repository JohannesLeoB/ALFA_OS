import Design
import Hub
import Shell
import SwiftUI

struct IntegrationList: View {
    @Environment(\.appearance) private var appearance
    let context: SettingsContext
    @State private var grids: [TileGroup: CGRect] = [:]
    @State private var scroll = ScrollReading()

    private var state: SettingsState { context.state }

    nonisolated private static let space = "tiles"

    private static let inset = Tokens.Spacing.step8

    private static let labelHeight = Tokens.Spacing.step24

    private static let labelGap = Tokens.Spacing.step8

    private static let reach = inset + labelHeight

    private static let tailRoom = Tokens.Spacing.step32

    var body: some View {
        let readings = context.readings
        let counts: [TileGroup: Int] = [.integrations: readings.count, .keys: 1]
        let current = active
        ScrollView {
            VStack(alignment: .leading, spacing: CGFloat(Tokens.Spacing.step12)) {
                group(.integrations, active: current) {
                    ForEach(readings) { reading in
                        SettingsTile(
                            name: LocalizedStringKey(reading.info.nameKey),
                            initial: String(appearance.string(reading.info.nameKey).prefix(1)),
                            logo: reading.info.logo,
                            sub: reading.state.key,
                            bad: reading.state.isBad,
                            selected: state.front == reading.info.id,
                            action: { state.open(reading.info.id) })
                    }
                }
                group(.keys, active: current) {
                    let section = SettingsSection.keyInventory
                    SettingsTile(
                        name: LocalizedStringKey(section.key),
                        initial: String(appearance.string(section.key).prefix(1)),
                        logo: nil,
                        sub: state.detailKey(of: section),
                        bad: false,
                        selected: state.front == section.rawValue,
                        action: { state.open(section.rawValue) })
                }
            }
            .padding(CGFloat(Self.inset))
            .coordinateSpace(name: Self.space)
        }
        .scrollIndicators(.never)
        .scrollTargetBehavior(TileScrollTargetBehavior(rows: rows(counts)))
        .onScrollGeometryChange(for: ScrollReading.self) { geometry in
            ScrollReading(offset: Double(geometry.contentOffset.y + geometry.contentInsets.top),
                          viewport: Double(geometry.containerSize.height), content: Double(geometry.contentSize.height))
        } action: { _, reading in scroll = reading }
        .onChange(of: active, initial: true) { _, group in context.tiles.group = group }
        .onDisappear { context.tiles.group = nil }
    }

    private var active: TileGroup {
        let order = TileGroup.allCases
        let tops = order.map { group in grids[group].map { Double($0.minY) } ?? .infinity }
        let index = TileGrid.active(tops: tops, offset: scroll.offset, reach: Self.reach,
                                    viewport: scroll.viewport, content: scroll.content)
        return order[index]
    }

    private func rows(_ counts: [TileGroup: Int]) -> [Double] {
        grids.flatMap { entry -> [Double] in
            let frame = entry.value
            let columns = TileGrid.columns(width: Double(frame.width), minimum: Tokens.Size.settingsTileMinWidth, gap: Tokens.Spacing.step8)
            return TileGrid.rowTops(top: Double(frame.minY), count: counts[entry.key] ?? 0, columns: columns,
                                    height: Tokens.Size.settingsTileHeight, gap: Tokens.Spacing.step8)
        }
        .sorted()
    }

    private func group<Content: View>(_ group: TileGroup, active: TileGroup, @ViewBuilder content: () -> Content) -> some View {
        let first = group == TileGroup.allCases.first
        let last = group == TileGroup.allCases.last
        return VStack(alignment: .leading, spacing: first ? 0 : CGFloat(Self.labelGap)) {
            if !first {
                appearance.text(group.key)
                    .designText(\.inkTertiary, size: Tokens.TextSize.small)
                    .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
                    .frame(height: CGFloat(Self.labelHeight), alignment: .bottomLeading)
                    .opacity(group == active ? 0 : 1)
                    .animation(appearance.ease(Tokens.Duration.hover), value: group == active)
            }
            TileFlowLayout(minimum: Tokens.Size.settingsTileMinWidth, gap: Tokens.Spacing.step8, height: Tokens.Size.settingsTileHeight) {
                content()
            }
            .transaction { $0.animation = nil }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { grids[group] = $0 }
        }
        .frame(minHeight: last ? CGFloat(max(0, scroll.viewport - 2 * Self.inset + Self.tailRoom)) : nil, alignment: .top)
    }
}

private struct ScrollReading: Equatable {
    var offset = 0.0
    var viewport = 0.0
    var content = 0.0
}
