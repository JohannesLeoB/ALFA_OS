import SwiftUI

public extension View {
    /// Casts the shadow of the contract. A shadow without blur casts none.
    /// SwiftUI takes a radius for the blur; the radius is half the blur of the contract, an approximation.
    func themeShadow(_ token: ShadowToken) -> some View {
        modifier(ThemeShadowModifier(token: token))
    }
}

struct ThemeShadowModifier: ViewModifier {
    let token: ShadowToken
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let spec = theme.shadow(token, scheme)
        content.shadow(color: Color(spec.color), radius: spec.blur / 2, x: spec.x, y: spec.y)
    }
}
