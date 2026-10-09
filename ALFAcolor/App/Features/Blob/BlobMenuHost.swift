import SwiftUI
import AppTheme
import BoardModel
import Motion

/// The blob menu over the canvas, shown in blob mode. One glass blob sits at the top center, or at the edge
/// it is pinned to. A tap spreads it into its palette. The row has one blob per palette. A drag moves the
/// single blob, and it sticks to the nearest edge when it is let go. The state, the placement and the timing
/// come from `Motion`; this view places and animates them.
struct BlobMenuHost: View {
    var shell: ShellState
    var store: BoardStore

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var glass
    /// Center of the single blob while a drag moves it. nil while it rests in its place.
    @State private var dragCenter: CGPoint?

    /// The picks of the palettes live in the model, so they survive a switch of the palette and the blob mode.
    private var unit: Binding<LengthUnit> {
        Binding(get: { shell.blobUnit }, set: { shell.blobUnit = $0 })
    }
    private var swatch: Binding<Int?> {
        Binding(get: { shell.blob.swatch }, set: { shell.blob.pickSwatch($0) })
    }
    private var token: Binding<Int?> {
        Binding(get: { shell.blob.token }, set: { shell.blob.pickToken($0) })
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let menu = shell.blob
            let metrics = BlobMetrics(theme: theme)
            let count = BlobPalette.allCases.count
            let anchor = BlobGeometry.anchor(layout: menu.layout, count: count, blob: metrics.blob, gap: metrics.gap,
                                             edge: menu.edge, container: size, margin: metrics.margin)
            let slots = BlobGeometry.slots(count: count, blob: metrics.blob, gap: metrics.gap,
                                           edge: menu.edge, anchor: anchor)
            let card = BlobGeometry.card(size: metrics.card, anchor: anchor, edge: menu.edge, container: size,
                                         margin: metrics.margin, gap: metrics.gap)
            let band = CGRect(x: anchor.minX - metrics.margin, y: anchor.maxY,
                              width: anchor.width + 2 * metrics.margin,
                              height: metrics.blob.height + metrics.margin)
            GlassEffectContainer(spacing: metrics.gap) {
                ZStack(alignment: .topLeading) {
                    if menu.open == nil && menu.pin == nil && dragCenter == nil {
                        ProgressiveBlurEdge()
                            .frame(width: band.width, height: band.height)
                            .position(x: band.midX, y: band.midY)
                    }
                    if menu.open != nil {
                        Color.clear
                            .contentShape(Rectangle())
                            .allowsHitTesting(true)
                            .onTapGesture { change { $0.close() } }
                    }
                    if menu.layout == .bar {
                        ForEach(BlobPalette.allCases, id: \.self) { palette in
                            let frame = slots[palette.index]
                            blob(palette, id: "bar.\(palette.rawValue)") { change { $0.select(palette) } }
                                .borderTrailPass(on: menu.open == palette, radius: .infinity)
                                .position(x: frame.midX, y: frame.midY)
                        }
                    } else if menu.open == nil {
                        homeBlob(anchor: anchor, size: size, metrics: metrics)
                    }
                    if let open = menu.open {
                        BlobCard(palette: open, direction: direction(to: open), menu: menu, store: store,
                                 unit: unit, swatch: swatch, token: token,
                                 onSelect: { next in change { $0.select(next) } },
                                 onLayout: { change { $0.toggleLayout() } },
                                 onPin: { edge in change { $0.pin(to: edge) } },
                                 onUnpin: { change { $0.unpin() } },
                                 onClose: { change { $0.close() } })
                            .frame(width: metrics.card.width, height: metrics.card.height)
                            .modifier(BlobGlass(shape: RoundedRectangle(cornerRadius: theme.radius(.l))))
                            .glassEffectID(menu.layout == .blob ? "home" : "card", in: glass)
                            .allowsHitTesting(true)
                            .position(x: card.midX, y: card.midY)
                    }
                }
                .frame(width: size.width, height: size.height, alignment: .topLeading)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Parts

    /// The single blob. A tap opens the last palette, and a drag moves it toward an edge.
    private func homeBlob(anchor: CGRect, size: CGSize, metrics: BlobMetrics) -> some View {
        let center = dragCenter ?? CGPoint(x: anchor.midX, y: anchor.midY)
        return blob(shell.blob.last, id: "home") { change { $0.tapBlob() } }
            .allowsHitTesting(true)
            .simultaneousGesture(drag(from: anchor, in: size, threshold: metrics.gap))
            .position(center)
    }

    /// One blob of the menu. A context menu holds the layout switch and the pin.
    private func blob(_ palette: BlobPalette, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: palette.symbol)
                .font(theme.text(.body).font)
                .frame(width: theme.space(.s6), height: theme.space(.s6))
        }
        .buttonStyle(.plain)
        .modifier(BlobGlass(shape: Circle()))
        .glassEffectID(id, in: glass)
        .allowsHitTesting(true)
        .accessibilityLabel(LocalizedStringKey(palette.titleKey))
        .contextMenu {
            Button(LocalizedStringKey("blob.layout.toggle")) { change { $0.toggleLayout() } }
            BlobPinMenu(pin: shell.blob.pin,
                        onPin: { edge in change { $0.pin(to: edge) } },
                        onUnpin: { change { $0.unpin() } })
        }
    }

    // MARK: - Motion

    /// The drag moves the blob with the pointer. Let go, it sticks to the edge nearest to it.
    private func drag(from anchor: CGRect, in size: CGSize, threshold: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: threshold)
            .onChanged { value in
                dragCenter = CGPoint(x: anchor.midX + value.translation.width,
                                     y: anchor.midY + value.translation.height)
            }
            .onEnded { value in
                let center = CGPoint(x: anchor.midX + value.translation.width,
                                     y: anchor.midY + value.translation.height)
                let edge = BlobGeometry.nearestEdge(to: center, in: size)
                withAnimation(animation(for: .pin)) {
                    dragCenter = nil
                    shell.blob.pin(to: edge)
                }
            }
    }

    /// Direction of a palette switch: the card slides forward when the new palette lies after the previous one.
    private func direction(to palette: BlobPalette) -> PanelDirection {
        guard let previous = shell.blob.previous else { return .still }
        return PanelDirection(from: previous.index, to: palette.index)
    }

    /// Applies a change of the menu with the motion that the change runs.
    private func change(_ update: (inout BlobMenu) -> Void) {
        var next = shell.blob
        update(&next)
        withAnimation(animation(for: BlobMotion.transition(from: shell.blob, to: next))) {
            shell.blob = next
        }
    }

    /// The easing of `Motion` for the duration of a transition. Reduced motion, or no change, gives no animation.
    private func animation(for transition: BlobTransition?) -> Animation? {
        guard let transition else { return nil }
        let milliseconds = BlobMotion.milliseconds(for: transition, reduceMotion: reduceMotion)
        guard milliseconds > 0 else { return nil }
        let curve = BlobMotion.easing
        return .timingCurve(curve.x1, curve.y1, curve.x2, curve.y2, duration: Double(milliseconds) / 1000)
    }
}

/// The sizes of the menu, all from the theme.
struct BlobMetrics {
    let blob: CGSize
    let gap: CGFloat
    let margin: CGFloat
    let card: CGSize

    init(theme: Theme) {
        let diameter = theme.space(.s6)
        blob = CGSize(width: diameter, height: diameter)
        gap = theme.space(.s2)
        margin = theme.space(.s4)
        card = CGSize(width: theme.space(.s8) * 6, height: theme.space(.s8) * 8)
    }
}

extension BlobPalette {
    /// Position of the palette in `allCases`, which is the order of the row.
    var index: Int { BlobPalette.allCases.firstIndex(of: self) ?? 0 }
}
