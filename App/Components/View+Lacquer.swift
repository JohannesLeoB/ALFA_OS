import Design
import SwiftUI

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
