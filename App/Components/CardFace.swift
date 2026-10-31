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
