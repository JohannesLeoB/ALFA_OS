import AppKit
import Design
import Hub
import Shell
import SwiftUI

struct IntegrationList: View {
    @Environment(\.appearance) private var appearance
    let context: SettingsContext
    @State private var grids: [String: CGRect] = [:]
    @State private var scroll = ScrollReading()

    private var state: SettingsState { context.state }

    nonisolated private static let space = "tiles"

    static let integrations = "settings.tiles.integrations"

    private static let keys = "settings.tiles.keys"

    private static let order = [integrations, keys]

    var body: some View {
        let readings = context.readings
        let counts = [Self.integrations: readings.count, Self.keys: 1]
        let current = active
        ScrollView {
            VStack(alignment: .leading, spacing: CGFloat(Tokens.Spacing.step12)) {
                tileGroup(Self.integrations, active: current, first: true) {
                    ForEach(readings) { reading in
                        SettingsTile(
                            name: LocalizedStringKey(reading.info.nameKey),
                            initial: String(appearance.string(reading.info.nameKey).prefix(1)),
                            logo: image(reading.info.logo),
                            sub: reading.state.key,
                            bad: reading.state.isBad,
                            selected: state.front == reading.info.id && !state.fanned,
                            action: { state.open(reading.info.id) })
                    }
                }
                tileGroup(Self.keys, active: current, last: true) {
                    let section = SettingsSection.keyInventory
                    SettingsTile(
                        name: LocalizedStringKey(section.key),
                        initial: String(appearance.string(section.key).prefix(1)),
                        logo: nil,
                        sub: section.detailKey,
                        bad: false,
                        selected: state.front == section.rawValue && !state.fanned,
                        action: { state.open(section.rawValue) })
                }
            }
            .padding(CGFloat(Tokens.Spacing.step8))
            .coordinateSpace(name: Self.space)
        }
        .scrollIndicators(.never)
        .scrollTargetBehavior(TileScrollTargetBehavior(rows: rows(counts)))
        .onScrollGeometryChange(for: ScrollReading.self) { geometry in
            ScrollReading(offset: Double(geometry.contentOffset.y + geometry.contentInsets.top),
                          viewport: Double(geometry.containerSize.height), content: Double(geometry.contentSize.height))
        } action: { _, reading in scroll = reading }
        .onChange(of: active, initial: true) { _, key in state.tileGroup = key }
        .onDisappear { state.tileGroup = nil }
    }

    private var active: String {
        let tops = Self.order.map { key in grids[key].map { Double($0.minY) } ?? .infinity }
        let index = TileGrid.active(tops: tops, offset: scroll.offset, reach: Tokens.Spacing.step8 + Tokens.Spacing.step24,
                                    viewport: scroll.viewport, content: scroll.content)
        return Self.order[index]
    }

    private func rows(_ counts: [String: Int]) -> [Double] {
        grids.flatMap { entry -> [Double] in
            let frame = entry.value
            let columns = TileGrid.columns(width: Double(frame.width), minimum: Tokens.Size.settingsTileMinWidth, gap: Tokens.Spacing.step8)
            return TileGrid.rowTops(top: Double(frame.minY), count: counts[entry.key] ?? 0, columns: columns,
                                    height: Tokens.Size.settingsTileHeight, gap: Tokens.Spacing.step8)
        }
        .sorted()
    }

    private func image(_ logo: IntegrationLogo?) -> NSImage? {
        guard let logo, let url = Bundle.main.url(forResource: logo.resource, withExtension: logo.fileExtension) else { return nil }
        return NSImage(contentsOf: url)
    }

    private func tileGroup<Content: View>(_ key: String, active: String, first: Bool = false, last: Bool = false,
                                          @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: first ? 0 : CGFloat(Tokens.Spacing.step8)) {
            if !first {
                appearance.text(key)
                    .designText(\.inkTertiary, size: Tokens.TextSize.small)
                    .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
                    .frame(height: CGFloat(Tokens.Spacing.step24), alignment: .bottomLeading)
                    .opacity(key == active ? 0 : 1)
                    .animation(appearance.ease(Tokens.Duration.hover), value: key == active)
            }
            TileFlowLayout(minimum: Tokens.Size.settingsTileMinWidth, gap: Tokens.Spacing.step8, height: Tokens.Size.settingsTileHeight) {
                content()
            }
            .transaction { $0.animation = nil }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { grids[key] = $0 }
        }
        .frame(minHeight: last ? CGFloat(max(0, scroll.viewport - 2 * Tokens.Spacing.step8 + Tokens.Spacing.step32)) : nil, alignment: .top)
    }
}

private struct ScrollReading: Equatable {
    var offset = 0.0
    var viewport = 0.0
    var content = 0.0
}

struct TileFlowLayout: Layout {
    let minimum: Double
    let gap: Double
    let height: Double

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? minimum
        let count = TileGrid.columns(width: Double(width), minimum: minimum, gap: gap)
        let rows = (subviews.count + count - 1) / count
        let total = rows == 0 ? 0 : Double(rows) * height + Double(rows - 1) * gap
        return CGSize(width: width, height: CGFloat(total))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let count = TileGrid.columns(width: Double(bounds.width), minimum: minimum, gap: gap)
        let cell = TileGrid.columnWidth(width: Double(bounds.width), count: count, gap: gap)
        for (index, view) in subviews.enumerated() {
            let x = bounds.minX + CGFloat(Double(index % count) * (cell + gap))
            let y = bounds.minY + CGFloat(Double(index / count) * (height + gap))
            view.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(width: CGFloat(cell), height: CGFloat(height)))
        }
    }
}
