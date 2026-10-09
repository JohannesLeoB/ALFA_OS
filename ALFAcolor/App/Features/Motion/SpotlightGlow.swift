import SwiftUI
import AppTheme
import Motion

extension View {
    /// Lights the view with a soft spot that follows the pointer. The spot is off with reduced transparency.
    func spotlight() -> some View {
        modifier(SpotlightGlow())
    }
}

private struct SpotlightGlow: ViewModifier {
    @State private var pointer: CGPoint?

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .onContinuousHover { phase in
                switch phase {
                case .active(let location): pointer = location
                case .ended: pointer = nil
                }
            }
            .overlay {
                if !reduceTransparency {
                    GeometryReader { proxy in
                        let size = proxy.size
                        let center = Spotlight.center(of: pointer, in: size)
                        RadialGradient(colors: [theme.color(.accent, scheme).opacity(Spotlight.strength), .clear],
                                       center: UnitPoint(x: center.x, y: center.y),
                                       startRadius: 0,
                                       endRadius: Spotlight.radius(in: size))
                    }
                    .allowsHitTesting(false)
                }
            }
    }
}
