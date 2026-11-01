import Design
import Shell
import SwiftUI

struct CardFace<Head: View, Content: View>: View {
    @Environment(\.appearance) private var appearance
    let depth: Int
    var lacquered = false
    var last = false
    let bring: () -> Void
    @ViewBuilder let head: (Color) -> Head
    @ViewBuilder let content: () -> Content
    @State private var hovering = false

    private var front: Bool { depth == 0 }

    private var step: StackStep? {
        guard depth > 0 else { return nil }
        return appearance.stackStep(CardStackEngine.levelIndex(depth: depth))
    }

    private var fill: Color { step.map { appearance.paint($0.surface) } ?? appearance.color(\.lane) }
    private var ink: Color { step.map { appearance.paint($0.ink) } ?? appearance.color(\.ink) }
    private var shape: UnevenRoundedRectangle {
        let top = CGFloat(Tokens.Radius.card)
        let bottom = CGFloat(Tokens.Radius.cardBottom)
        return UnevenRoundedRectangle(topLeadingRadius: top, bottomLeadingRadius: bottom, bottomTrailingRadius: bottom, topTrailingRadius: top)
    }

    var body: some View {
        VStack(spacing: 0) {
            head(ink)
            if front { content() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .foregroundStyle(ink)
        .background(fill.animation(appearance.ease(Tokens.Duration.stackBackground), value: depth))
        .modifier(CardFinish(lacquered: lacquered, last: last, front: front, step: step, shape: shape))
        .contentShape(shape)
        .offset(y: !front && hovering ? -CGFloat(Tokens.Spacing.step4) : 0)
        .onHover { hovering = $0 }
        .onTapGesture { if !front { bring() } }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(front ? [] : .isButton)
        .accessibilityAction { if !front { bring() } }
        .animation(appearance.ease(Tokens.Duration.stackLift), value: hovering)
    }
}

private struct CardFinish: ViewModifier {
    @Environment(\.appearance) private var appearance
    let lacquered: Bool
    let last: Bool
    let front: Bool
    let step: StackStep?
    let shape: UnevenRoundedRectangle

    @ViewBuilder
    func body(content: Content) -> some View {
        if lacquered {
            content.lacquer(shape, step: step, seam: front ? \.stackSeamFront : \.stackSeamBack, drop: !last, up: true)
        } else {
            content
                .overlay(alignment: .top) {
                    Rectangle().fill(appearance.color(\.glaze)).frame(height: CGFloat(Tokens.Size.hairline))
                }
                .clipShape(shape)
                .background { CardCast(front: front, shape: shape) }
        }
    }
}

private struct CardCast: View {
    @Environment(\.appearance) private var appearance
    let front: Bool
    let shape: UnevenRoundedRectangle

    var body: some View {
        let line = CGFloat(Tokens.Size.hairline)
        ZStack {
            shape.fill(appearance.color(\.line)).padding(-line)
            if front {
                soft(spread: Tokens.Size.stackFlatFrontSpread, blur: Tokens.Size.stackFlatFrontBlur,
                     y: -Tokens.Size.stackFlatFrontOffset, color: \.stackFlatFront)
            } else {
                shape.fill(appearance.color(\.stackRing)).padding(-line)
                soft(spread: Tokens.Size.stackFlatDropSpread, blur: Tokens.Size.stackFlatDropBlur,
                     y: -Tokens.Size.stackFlatDropOffset, color: \.stackFlatDrop)
            }
        }
    }

    private func soft(spread: Double, blur: Double, y: Double, color: KeyPath<Colors, ColorValue>) -> some View {
        shape.inset(by: CGFloat(-spread))
            .fill(appearance.color(color))
            .blur(radius: CGFloat(blur / 2))
            .offset(y: CGFloat(y))
    }
}

struct CardHeader<Mark: View, Title: View, Meta: View, Trailing: View>: View {
    let front: Bool
    let ink: Color
    @ViewBuilder let mark: Mark
    @ViewBuilder let title: Title
    @ViewBuilder let meta: Meta
    @ViewBuilder let trailing: Trailing

    var body: some View {
        let side = CGFloat(Tokens.Size.symbolSize)
        HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
            mark
                .typeStyle(Tokens.TextStyle.mark)
                .lineLimit(1)
                .frame(width: side, height: side)
                .overlay(Circle().strokeBorder(ink.opacity(Tokens.Opacity.ringOnMark), lineWidth: CGFloat(Tokens.Size.hairline)))
                .padding(.trailing, CGFloat(Tokens.Spacing.step12))
            title.layoutPriority(1)
            meta
            trailing
        }
        .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
        .frame(height: CGFloat(Tokens.Spacing.step44))
        .overlay(alignment: .bottom) {
            if front { Hairline() }
        }
    }
}

struct CardHeadButton: View {
    @Environment(\.appearance) private var appearance
    let help: String
    let glyph: Icon
    let ink: Color
    var dim = true
    var fills = true
    var pressed = true
    var disabled = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let side = CGFloat(Tokens.Size.symbolSize)
        Button(action: action) {
            Glyph(glyph)
                .frame(width: side, height: side)
                .foregroundStyle(ink)
                .opacity(disabled ? Tokens.Opacity.disabled : hovering || !dim ? 1 : SheetValues.closeOpacity)
                .background(Circle().fill(hovering && fills ? appearance.color(\.hover) : Color.clear))
                .contentShape(Circle())
        }
        .buttonStyle(PressScaleButtonStyle(scale: pressed ? Tokens.Scale.pressButton : 1))
        .disabled(disabled)
        .help(Text(verbatim: help))
        .accessibilityLabel(Text(verbatim: help))
        .onHover { hovering = $0 }
    }
}

struct CardStack<Item: Hashable, Card: View, Over: View>: View {
    @Environment(\.appearance) private var appearance
    let order: [Item]
    let overviewOpen: Bool
    @ViewBuilder let card: (Item, Int) -> Card
    @ViewBuilder let overview: () -> Over

    var body: some View {
        GeometryReader { proxy in
            let tops = CardStackEngine.tops(count: order.count)
            let shape = RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.card))
            ZStack(alignment: .top) {
                if order.isEmpty {
                    shape
                        .fill(appearance.color(\.lane))
                        .overlay(shape.strokeBorder(appearance.color(\.line), lineWidth: CGFloat(Tokens.Size.hairline)))
                        .accessibilityLabel(appearance.text("stack.empty"))
                }
                ZStack(alignment: .top) {
                    ForEach(Array(order.enumerated()), id: \.element) { index, item in
                        card(item, order.count - 1 - index)
                            .frame(width: max(0, proxy.size.width - 2 * CGFloat(Tokens.Size.cardInset)),
                                   height: max(0, proxy.size.height - CGFloat(tops[index])))
                            .offset(y: CGFloat(tops[index]))
                            .zIndex(Double(index))
                            .opacity(overviewOpen ? 0 : 1)
                            .animation(overviewOpen ? appearance.ease(Tokens.Duration.toggle, SheetValues.cssEase)
                                       : appearance.ease(Tokens.Duration.overviewDelay, SheetValues.cssEase, delay: Tokens.Duration.reelStagger),
                                       value: overviewOpen)
                            .offset(y: overviewOpen ? CGFloat(Tokens.Spacing.step8) : 0)
                            .animation(appearance.ease(Tokens.Duration.stackLift), value: overviewOpen)
                            .allowsHitTesting(!overviewOpen)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                .zIndex(Double(Tokens.Layer.lane))
                if overviewOpen {
                    overview()
                        .zIndex(Double(Tokens.Layer.inLaneOverview))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .animation(appearance.ease(Tokens.Transition.stack), value: order)
        }
    }
}

private struct Lacquer: ViewModifier {
    @Environment(\.appearance) private var appearance
    let shape: UnevenRoundedRectangle
    let gloss: KeyPath<Colors, ColorValue>
    let seam: KeyPath<Colors, ColorValue>
    let drop: Bool
    let shown: Bool
    let up: Bool

    func body(content: Content) -> some View {
        let line = CGFloat(Tokens.Size.hairline)
        content
            .overlay(alignment: up ? .top : .bottom) {
                Rectangle().fill(shown ? appearance.color(gloss) : Color.clear).frame(height: line)
            }
            .clipShape(shape)
            .background {
                ZStack {
                    if drop && shown {
                        shape.inset(by: CGFloat(-Tokens.Size.stackDropSpread))
                            .fill(appearance.color(\.stackDrop))
                            .blur(radius: CGFloat(Tokens.Size.stackDropBlur / 2))
                            .offset(y: CGFloat(up ? -Tokens.Size.stackDropOffset : Tokens.Size.stackDropOffset))
                    }
                    shape.fill(shown ? appearance.color(seam) : Color.clear).offset(y: up ? -line : line)
                }
            }
    }
}

private func gloss(of step: StackStep?) -> KeyPath<Colors, ColorValue> {
    guard let step else { return \.stackGlossFront }
    return step.surface.red >= SheetValues.stackGlossLightFrom ? \.stackGlossLight : \.stackGlossDark
}

extension View {
    func lacquer(_ shape: UnevenRoundedRectangle, step: StackStep?, seam: KeyPath<Colors, ColorValue>, drop: Bool,
                 shown: Bool = true, up: Bool = false) -> some View {
        lacquer(shape, gloss: gloss(of: step), seam: seam, drop: drop, shown: shown, up: up)
    }

    func lacquer(_ shape: UnevenRoundedRectangle, gloss: KeyPath<Colors, ColorValue>, seam: KeyPath<Colors, ColorValue>,
                 drop: Bool, shown: Bool = true, up: Bool = false) -> some View {
        modifier(Lacquer(shape: shape, gloss: gloss, seam: seam, drop: drop, shown: shown, up: up))
    }
}
