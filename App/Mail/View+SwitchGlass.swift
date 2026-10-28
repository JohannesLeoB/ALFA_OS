import Design
import SwiftUI

private struct SwitchGlass: ViewModifier {
    @Environment(\.appearance) private var appearance
    let on: Bool

    func body(content: Content) -> some View {
        content.overlay {
            Rectangle()
                .fill(appearance.color(\.lane).opacity(Tokens.Opacity.switchGlass))
                .opacity(on ? 1 : 0)
                .allowsHitTesting(false)
                .zIndex(Double(Tokens.Layer.switchGlass))
        }
    }
}

extension View {
    func switchGlass(_ on: Bool) -> some View {
        modifier(SwitchGlass(on: on))
    }
}
