import Design
import Shell
import SwiftUI

struct DeskLane: View {
    let session: AppSession
    let lane: LaneKind
    let titleKey: String
    let size: CGSize
    @Environment(\.appearance) private var appearance

    private var desk: DeskState { session.desk }

    private var pane: (any Pane)? { session.panes[desk.currentID] }

    private var title: PaneTitle { pane?.title(lane) ?? .key(titleKey) }

    private var name: PaneTitle { pane?.name(lane) ?? .key(titleKey) }

    private var ownsHead: Bool { pane?.ownsHead(lane) ?? false }

    var body: some View {
        let measure = desk.measure
        let shape = RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.lane))
        let folded = Double(size.width) <= measure.laneFolded
        let strip = Double(size.width) < measure.foldAt
        let inner = max(size.width, CGFloat(desk.minimum[lane.index]))
        let fade = appearance.ease(Tokens.Duration.hover)
        ZStack(alignment: .topLeading) {
            if folded {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { desk.openStrip(lane) }
                    .pointerStyle(.link)
            }
            marks
                .frame(width: size.width, height: size.height, alignment: .top)
                .opacity(strip ? 1 : 0)
                .allowsHitTesting(strip)
                .accessibilityHidden(!strip)
                .animation(fade, value: strip)
            VStack(spacing: 0) {
                if !ownsHead { header }
                content
            }
            .frame(width: inner, height: size.height, alignment: .topLeading)
            .opacity(strip ? 0 : 1)
            .allowsHitTesting(!strip)
            .accessibilityHidden(strip)
            .animation(fade, value: strip)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .background(appearance.color(\.lane))
        .clipShape(shape)
        .shadowLayers(shape, \.lane)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title.text(appearance))
    }

    @ViewBuilder
    private var marks: some View {
        if let marks = pane?.marks(lane, height: Double(size.height)) { marks }
    }

    @ViewBuilder
    private var content: some View {
        if let pane { pane.content(lane) } else { Color.clear.frame(maxHeight: .infinity) }
    }

    private var header: some View {
        LaneHead(lane: lane) {
            if !(pane?.hidesTitle(lane) ?? false) { HeaderTitle(text: title.text(appearance)) }
            Spacer(minLength: 0)
            tools
        }
    }

    @ViewBuilder
    private var tools: some View {
        let open = desk.widths.all.filter { $0 > desk.measure.laneFolded }.count
        let name = self.name.string(appearance)
        if open > 1 {
            SymbolButton(help: appearance.format("mail.fold.named", name), glyph: .minus, pressed: lane != .center) { desk.toggleFold(lane) }
        }
        if lane == .center {
            let maxed = desk.laneMode(desk.currentID).maximized == .center
            SymbolButton(help: maxed ? appearance.string("mail.lane.back") : appearance.format("mail.grow.named", name),
                         glyph: maxed ? .shrink : .expand, pressed: false) { desk.toggleMaximize(.center) }
        }
    }
}
