import Design
import Shell
import SwiftUI

struct CardFace<Head: View, Content: View>: View {
    @Environment(\.appearance) private var appearance
    let depth: Int
    let bring: () -> Void
    @ViewBuilder let head: (Color) -> Head
    @ViewBuilder let content: () -> Content
    @State private var hovering = false

    private var front: Bool { depth == 0 }

    private var step: StackStep? {
        guard depth > 0 else { return nil }
        let steps = appearance.dark ? Tokens.stackDark : Tokens.stackLight
        return steps[min(CardStackEngine.levelIndex(depth: depth), steps.count - 1)]
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
        .background(fill)
        .overlay(alignment: .top) {
            Rectangle().fill(appearance.color(\.glaze)).frame(height: CGFloat(Tokens.Size.hairline))
        }
        .clipShape(shape)
        .background { cast }
        .contentShape(shape)
        .offset(y: !front && hovering ? -CGFloat(SheetValues.stackHoverLift) : 0)
        .onHover { hovering = $0 }
        .onTapGesture { if !front { bring() } }
        .animation(appearance.ease(Tokens.Duration.stackLift), value: hovering)
    }

    private var cast: some View {
        let line = CGFloat(Tokens.Size.hairline)
        return ZStack {
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
