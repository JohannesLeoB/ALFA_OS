import Design
import SwiftUI

private struct ShadowLayers<S: InsettableShape>: ViewModifier {
    @Environment(\.appearance) private var appearance
    let layers: KeyPath<Shadows, [ShadowLayer]>
    let shape: S

    func body(content: Content) -> some View {
        let visible = appearance.shadows[keyPath: layers].filter { !$0.inset }
        return visible.reduce(AnyView(content)) { view, layer in
            let color = appearance.paint(layer.color)
            if layer.isContour {
                return AnyView(view.background(shape.fill(color).padding(-CGFloat(layer.spread))))
            }
            return AnyView(view.shadow(color: color, radius: CGFloat(layer.blur / 2), x: CGFloat(layer.x), y: CGFloat(layer.y)))
        }
    }
}

extension View {
    func shadowLayers<S: InsettableShape>(_ shape: S, _ layers: KeyPath<Shadows, [ShadowLayer]> = \.floating) -> some View {
        modifier(ShadowLayers(layers: layers, shape: shape))
    }
}
