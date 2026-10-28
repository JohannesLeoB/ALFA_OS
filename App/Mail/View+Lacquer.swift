import Design
import SwiftUI

private struct Lacquer: ViewModifier {
    @Environment(\.appearance) private var appearance
    let shape: UnevenRoundedRectangle
    let gloss: KeyPath<Colors, ColorValue>
    let seam: KeyPath<Colors, ColorValue>
    let drop: Bool
    let shown: Bool

    func body(content: Content) -> some View {
        let line = CGFloat(Tokens.Size.hairline)
        content
            .overlay(alignment: .bottom) {
                Rectangle().fill(shown ? appearance.color(gloss) : Color.clear).frame(height: line)
            }
            .clipShape(shape)
            .background {
                ZStack {
                    if drop && shown {
                        shape.inset(by: CGFloat(-Tokens.Size.stackDropSpread))
                            .fill(appearance.color(\.stackDrop))
                            .blur(radius: CGFloat(Tokens.Size.stackDropBlur / 2))
                            .offset(y: CGFloat(Tokens.Size.stackDropOffset))
                    }
                    shape.fill(shown ? appearance.color(seam) : Color.clear).offset(y: line)
                }
            }
    }
}

extension View {
    func lacquer(_ shape: UnevenRoundedRectangle, gloss: KeyPath<Colors, ColorValue>, seam: KeyPath<Colors, ColorValue>,
                 drop: Bool, shown: Bool = true) -> some View {
        modifier(Lacquer(shape: shape, gloss: gloss, seam: seam, drop: drop, shown: shown))
    }
}
