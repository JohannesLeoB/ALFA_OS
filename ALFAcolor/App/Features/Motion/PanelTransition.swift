import SwiftUI
import Motion

extension AnyTransition {
    /// Slides a panel toward its direction and fades it. A forward panel enters from the trailing side.
    static func panel(_ direction: PanelDirection, distance: CGFloat) -> AnyTransition {
        let offset = distance * CGFloat(direction.sign)
        return .asymmetric(
            insertion: .modifier(active: PanelSlide(offset: offset, opacity: 0),
                                 identity: PanelSlide(offset: 0, opacity: 1)),
            removal: .modifier(active: PanelSlide(offset: -offset, opacity: 0),
                               identity: PanelSlide(offset: 0, opacity: 1))
        )
    }
}

/// The offset and opacity of a panel on its way in or out.
private struct PanelSlide: ViewModifier {
    let offset: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .opacity(opacity)
    }
}
