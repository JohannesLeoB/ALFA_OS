import Design
import SwiftUI

private struct SwitchGlass: ViewModifier {
    @Environment(\.appearance) private var appearance
    @Environment(\.session) private var session

    func body(content: Content) -> some View {
        let on = session?.mailboxSwitching ?? false
        let timing = on ? appearance.ease(Tokens.Duration.switchIn, Tokens.Easing.glassIn) : appearance.ease(Tokens.Duration.switchOut, Tokens.Easing.glassOut)
        content.overlay {
            Rectangle()
                .fill(appearance.color(\.lane).opacity(Tokens.Opacity.switchGlass))
                .opacity(on ? 1 : 0)
                .animation(timing, value: on)
                .allowsHitTesting(false)
        }
    }
}

extension View {
    func switchGlass() -> some View {
        modifier(SwitchGlass())
    }
}
