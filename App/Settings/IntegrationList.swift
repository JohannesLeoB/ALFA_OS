import AppKit
import Design
import Hub
import Shell
import SwiftUI

struct IntegrationList: View {
    @Environment(\.appearance) private var appearance
    let context: SettingsContext

    private var state: SettingsState { context.state }

    var body: some View {
        let readings = context.readings
        ScrollView {
            VStack(alignment: .leading, spacing: CGFloat(Tokens.Spacing.step16)) {
                tileGroup("settings.tiles.integrations") {
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
                tileGroup("settings.tiles.keys") {
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
            .padding(.horizontal, CGFloat(Tokens.Spacing.step16))
            .padding(.top, CGFloat(Tokens.Spacing.step8))
            .padding(.bottom, CGFloat(Tokens.Spacing.step16))
        }
        .scrollIndicators(.never)
    }

    private func image(_ logo: IntegrationLogo?) -> NSImage? {
        guard let logo, let url = Bundle.main.url(forResource: logo.resource, withExtension: logo.fileExtension) else { return nil }
        return NSImage(contentsOf: url)
    }

    private func tileGroup<Content: View>(_ key: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: CGFloat(Tokens.Spacing.step8)) {
            appearance.text(key)
                .designText(\.inkTertiary, size: Tokens.TextSize.small)
                .padding(.horizontal, CGFloat(Tokens.Spacing.step4))
                .frame(height: CGFloat(Tokens.Spacing.step24), alignment: .bottomLeading)
            TileFlowLayout(minimum: Tokens.Size.settingsTileMinWidth, gap: Tokens.Spacing.step8, height: Tokens.Size.settingsTileHeight) {
                content()
            }
            .transaction { $0.animation = nil }
        }
    }
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
