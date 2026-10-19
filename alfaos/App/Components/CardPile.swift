import ShellCore
import SwiftUI

struct CardPile<Item: Hashable, Card: View, Over: View, Note: View>: View {
    @Environment(\.design) private var design
    @Environment(\.laneFill) private var laneFill
    @Environment(\.hairline) private var hairline
    @Environment(\.accessibilityReduceMotion) private var reduced
    let order: [Item]
    let fanned: Bool
    @ViewBuilder let card: (Item, Int, Bool) -> Card
    @ViewBuilder let overview: () -> Over
    @ViewBuilder let note: () -> Note

    var body: some View {
        GeometryReader { proxy in
            let tops = CardStack.tops(count: order.count)
            ZStack(alignment: .top) {
                if order.isEmpty {
                    RoundedRectangle(cornerRadius: CGFloat(Design.Radius.card))
                        .fill(laneFill)
                        .overlay(RoundedRectangle(cornerRadius: CGFloat(Design.Radius.card)).strokeBorder(design.color(\.line), lineWidth: hairline))
                        .accessibilityLabel(word("stack.empty"))
                }
                ForEach(Array(order.enumerated()), id: \.element) { index, item in
                    card(item, order.count - 1 - index, index == 0)
                        .frame(width: proxy.size.width, height: max(0, proxy.size.height - CGFloat(tops[index])))
                        .offset(y: CGFloat(tops[index]))
                        .zIndex(Double(index))
                        .opacity(fanned ? 0 : 1)
                        .allowsHitTesting(!fanned)
                }
                if fanned {
                    overview()
                        .zIndex(Double(order.count + 1))
                }
                VStack {
                    Spacer(minLength: 0)
                    note()
                        .padding(.bottom, CGFloat(SheetValues.toastBottom))
                }
                .zIndex(Double(order.count + 2))
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .animation(ComponentMotion(reduced: reduced).curve(Design.Duration.stack, Design.Easing.stack), value: order)
        }
    }
}

struct CardFace<Head: View, Content: View>: View {
    @Environment(\.design) private var design
    @Environment(\.laneFill) private var laneFill
    @Environment(\.cardSurface) private var surface
    @Environment(\.hairline) private var hairline
    @Environment(\.accessibilityReduceMotion) private var reduced
    let depth: Int
    let first: Bool
    let bring: () -> Void
    @ViewBuilder let head: (Color) -> Head
    @ViewBuilder let content: () -> Content
    @State private var hovering = false

    private var front: Bool { depth == 0 }

    private var step: DesignStackStep? {
        guard depth > 0 else { return nil }
        let steps = design.dark ? Design.stackDark : Design.stackLight
        return steps[min(CardStack.levelIndex(depth: depth), steps.count - 1)]
    }

    private func paint(_ value: RGB) -> Color {
        Color(.sRGB, red: value.red, green: value.green, blue: value.blue, opacity: value.alpha)
    }

    private var fill: Color { step.map { paint($0.surface) } ?? laneFill }
    private var ink: Color { step.map { paint($0.ink) } ?? design.color(\.ink) }
    private var lacquer: Bool { surface == .lacquer }
    private var light: Bool { step.map { $0.surface.red >= SheetValues.lightSurfaceRed } ?? true }

    private var shape: UnevenRoundedRectangle {
        let top = CGFloat(Design.Radius.card)
        let bottom = CGFloat(Design.Radius.cardBottom)
        return UnevenRoundedRectangle(topLeadingRadius: top, bottomLeadingRadius: bottom, bottomTrailingRadius: bottom, topTrailingRadius: top)
    }

    var body: some View {
        VStack(spacing: 0) {
            head(ink)
            if front { content() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .foregroundStyle(ink)
        .background(fill)
        .overlay(alignment: .top) { gloss }
        .clipShape(shape)
        .background { cast }
        .contentShape(shape)
        .offset(y: !front && hovering ? -CGFloat(SheetValues.stackHoverLift) : 0)
        .onHover { hovering = $0 }
        .onTapGesture { if !front { bring() } }
        .animation(ComponentMotion(reduced: reduced).curve(Design.Duration.stackLift), value: hovering)
    }

    @ViewBuilder
    private var gloss: some View {
        let layers: [ShadowLayer] = front
            ? (design.dark ? DesignSurface.topGlossFrontDark : DesignSurface.topGlossFrontLight)
            : (light ? DesignSurface.topGlossBackLightCard : DesignSurface.topGlossBackDarkCard)
        if lacquer, let layer = layers.first {
            Rectangle().fill(paint(layer.color)).frame(height: CGFloat(layer.y))
        } else if !lacquer {
            Rectangle().fill(design.color(\.glaze)).frame(height: hairline)
        }
    }

    @ViewBuilder
    private var cast: some View {
        if lacquer {
            let layer = (design.dark ? DesignSurface.castShadowDark : DesignSurface.castShadowLight).first
            let seam = (design.dark ? DesignSurface.topSeamDark : front ? DesignSurface.topSeamFrontLight : DesignSurface.topSeamBackLight).first
            ZStack {
                if let layer, !first { softShadow(layer) }
                if let seam { shape.fill(paint(seam.color)).offset(y: CGFloat(seam.y)) }
            }
        } else {
            ZStack {
                shape.fill(design.color(\.line)).padding(-hairline)
                if front {
                    soft(spread: SheetValues.cardFlatFrontSpread, blur: SheetValues.cardFlatFrontBlur, y: SheetValues.cardFlatFrontY,
                         alpha: SheetValues.cardFlatCast)
                } else {
                    shape.fill(Color.black.opacity(SheetValues.cardFlatBackRing)).padding(-hairline)
                    soft(spread: SheetValues.cardFlatBackSpread, blur: SheetValues.cardFlatBackBlur, y: SheetValues.cardFlatBackY,
                         alpha: SheetValues.cardFlatBackCast)
                }
            }
        }
    }

    private func softShadow(_ layer: ShadowLayer) -> some View {
        shape.inset(by: CGFloat(-layer.spread))
            .fill(paint(layer.color))
            .blur(radius: CGFloat(layer.blur / 2))
            .offset(x: CGFloat(layer.x), y: CGFloat(layer.y))
    }

    private func soft(spread: Double, blur: Double, y: Double, alpha: Double) -> some View {
        shape.inset(by: CGFloat(-spread))
            .fill(Color.black.opacity(alpha))
            .blur(radius: CGFloat(blur / 2))
            .offset(y: CGFloat(y))
    }
}

struct CardHeadButton: View {
    @Environment(\.design) private var design
    let help: String
    let glyph: Icon
    let ink: Color
    var dim = true
    var fills = true
    var pressed = true
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let side = CGFloat(Design.Size.symbolSize)
        Button(action: action) {
            Glyph(glyph)
                .frame(width: side, height: side)
                .foregroundStyle(ink)
                .opacity(hovering || !dim ? 1 : SheetValues.closeOpacity)
                .background(Circle().fill(hovering && fills ? design.color(\.hover) : Color.clear))
                .contentShape(Circle())
        }
        .buttonStyle(PressScale(scale: pressed ? SheetValues.pressScale : 1))
        .help(Text(verbatim: help))
        .accessibilityLabel(Text(verbatim: help))
        .onHover { hovering = $0 }
    }
}

enum OverviewMark {
    case text(String)
    case icon(Icon)
}

struct OverviewCommand: Identifiable {
    let id: String
    let help: String
    let icon: Icon
    let tone: KeyPath<DesignColors, RGB>
    let run: () -> Void
}

struct OverviewEntry: Identifiable {
    let id: String
    let mark: OverviewMark
    let title: Text
    let date: Text
    let unread: Bool
    let subject: String
    let preview: String
    let current: Bool
    var close: (() -> Void)?
    var commands: [OverviewCommand] = []
    let choose: () -> Void
}

struct CardOverview<Lead: View>: View {
    @Environment(\.design) private var design
    @Environment(\.laneFill) private var laneFill
    @Environment(\.hairline) private var hairline
    let entries: [OverviewEntry]
    let size: OverviewSize
    let resize: (OverviewSize) -> Void
    let hot: String?
    let aim: (String?) -> Void
    @ViewBuilder let lead: Lead

    private var sizes: [SegmentOption<OverviewSize>] {
        [SegmentOption(id: .small, label: word("overview.small")),
         SegmentOption(id: .medium, label: word("overview.medium")),
         SegmentOption(id: .large, label: word("overview.large"))]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: CGFloat(Design.Spacing.step8)) {
                lead
                Spacer(minLength: 0)
                SegmentedControl(options: sizes, selection: Binding(get: { size }, set: { resize($0) }))
            }
            .padding(.horizontal, CGFloat(Design.Spacing.step8))
            .frame(height: CGFloat(Design.Size.headerHeight))
            .overlay(alignment: .bottom) { Rectangle().fill(design.color(\.line)).frame(height: hairline) }
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: CGFloat(size.tileMinWidth)), spacing: CGFloat(Design.Spacing.step8), alignment: .top)],
                          spacing: CGFloat(Design.Spacing.step8)) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        OverviewTileView(entry: entry, index: index, size: size, hot: hot == entry.id,
                                         dimmed: hot != nil && hot != entry.id, aim: aim)
                    }
                }
                .padding(CGFloat(Design.Spacing.step8))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(laneFill)
    }
}

private struct OverviewTileView: View {
    @Environment(\.design) private var design
    @Environment(\.hairline) private var hairline
    @Environment(\.accessibilityReduceMotion) private var reduced
    let entry: OverviewEntry
    let index: Int
    let size: OverviewSize
    let hot: Bool
    let dimmed: Bool
    let aim: (String?) -> Void
    @State private var entered = false

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: CGFloat(Design.Radius.row)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            head
            VStack(alignment: .leading, spacing: CGFloat(Design.Spacing.step4)) {
                Text(verbatim: entry.subject)
                    .designText(\.ink, size: Design.TextSize.body, weight: .medium)
                    .lineLimit(SheetValues.overviewTitleLines)
                    .lineHeight(SheetValues.overviewTileTitleLine * Design.TextSize.body, size: Design.TextSize.body)
                Text(verbatim: entry.preview)
                    .designText(\.inkSecondary, size: Design.TextSize.body)
                    .lineLimit(size.lines)
                    .lineHeight(SheetValues.overviewTileTextLine * Design.TextSize.body, size: Design.TextSize.body)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, CGFloat(Design.Size.edge))
            .padding(.top, CGFloat(Design.Spacing.step4))
            .padding(.bottom, CGFloat(SheetValues.overviewTilePadBottom))
            Spacer(minLength: 0)
        }
        .frame(height: CGFloat(size.tileHeight))
        .background(shape.fill(design.color(\.well)))
        .ring(shape, entry.current ? design.color(\.inkTertiary) : design.color(\.line))
        .overlay(alignment: .bottomTrailing) { commands }
        .clipShape(shape)
        .contentShape(shape)
        .background {
            if hot, let layer = DesignShadows.overviewHoverLight.first {
                shape.inset(by: CGFloat(-layer.spread))
                    .fill(Color(.sRGB, red: layer.color.red, green: layer.color.green, blue: layer.color.blue, opacity: layer.color.alpha))
                    .blur(radius: CGFloat(layer.blur / 2))
                    .offset(x: CGFloat(layer.x), y: CGFloat(layer.y))
            }
        }
        .opacity(entered ? (dimmed ? SheetValues.overviewOtherOpacity : 1) : 0)
        .scaleEffect(entered ? (hot ? SheetValues.overviewHoverScale : dimmed ? SheetValues.overviewOtherScale : 1) : SheetValues.overviewEnterScale)
        .offset(y: entered ? (hot ? -Design.Size.overviewHoverLift : 0) : SheetValues.overviewEnterLift)
        .onAppear {
            guard !reduced else { entered = true; return }
            let curve = Design.Easing.standard
            withAnimation(.timingCurve(curve.x1, curve.y1, curve.x2, curve.y2, duration: Design.Duration.overviewEnter)
                .delay(Design.Duration.overviewDelay + Double(index) * Design.Duration.overviewStagger)) { entered = true }
        }
        .onHover { inside in
            if inside { aim(entry.id) } else if hot { aim(nil) }
        }
        .animation(ComponentMotion(reduced: reduced).curve(Design.Duration.tileHover), value: hot)
        .animation(ComponentMotion(reduced: reduced).curve(Design.Duration.tileHover), value: dimmed)
        .onTapGesture { entry.choose() }
    }

    private var head: some View {
        HStack(spacing: CGFloat(Design.Spacing.step8)) {
            Group {
                switch entry.mark {
                case .text(let text): Text(verbatim: text)
                case .icon(let icon): Glyph(icon)
                }
            }
            .designText(size: Design.TextSize.small, weight: .medium)
            .frame(width: CGFloat(Design.Size.symbolSize), height: CGFloat(Design.Size.symbolSize))
            .overlay(Circle().strokeBorder(design.color(\.ink).opacity(Design.Opacity.ringOnMark), lineWidth: hairline))
            .overlay(alignment: .topTrailing) {
                if entry.unread {
                    Circle().fill(design.color(\.ink))
                        .frame(width: CGFloat(Design.Spacing.statusDot), height: CGFloat(Design.Spacing.statusDot))
                        .overlay(Circle().strokeBorder(design.color(\.well), lineWidth: CGFloat(Design.Size.markSeparatorRing)))
                        .offset(x: CGFloat(SheetValues.unreadDotShift), y: -CGFloat(SheetValues.unreadDotShift))
                }
            }
            .padding(.trailing, CGFloat(Design.Spacing.step4))
            entry.title.designText(size: Design.TextSize.body, weight: .medium).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            entry.date.designText(\.inkTertiary, size: Design.TextSize.small).monospacedDigit().lineLimit(1).fixedSize()
            if let close = entry.close {
                CardHeadButton(help: words("card.close"), glyph: .close, ink: design.color(\.ink), pressed: false, action: close)
            }
        }
        .padding(.horizontal, CGFloat(Design.Spacing.step8))
        .frame(height: CGFloat(Design.Size.headerHeight))
    }

    @ViewBuilder
    private var commands: some View {
        if !entry.commands.isEmpty {
            HStack(spacing: CGFloat(Design.Spacing.step4)) {
                ForEach(entry.commands) { command in
                    SymbolButton(help: command.help, glyph: command.icon, tone: command.tone, hoverTone: command.tone, plate: \.lane,
                                 hover: .fill, action: command.run)
                }
            }
            .padding(CGFloat(Design.Spacing.step8))
            .opacity(hot ? 1 : 0)
            .offset(y: hot ? 0 : Design.Size.overviewActionsOffset)
            .allowsHitTesting(hot)
            .animation(ComponentMotion(reduced: reduced).curve(Design.Duration.tileActions), value: hot)
        }
    }
}
