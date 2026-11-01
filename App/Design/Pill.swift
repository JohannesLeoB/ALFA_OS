import Design
import SwiftUI

struct Pill: InsettableShape {
    var inset = CGFloat.zero

    func path(in rect: CGRect) -> Path {
        let box = rect.insetBy(dx: inset, dy: inset)
        guard box.width > box.height else { return Path(ellipseIn: box) }
        let radius = box.height / 2
        var path = Path()
        path.move(to: CGPoint(x: box.minX + radius, y: box.minY))
        path.addLine(to: CGPoint(x: box.maxX - radius, y: box.minY))
        path.addArc(center: CGPoint(x: box.maxX - radius, y: box.midY), radius: radius, startAngle: .degrees(-SheetValues.quarterTurn), endAngle: .degrees(SheetValues.quarterTurn), clockwise: false)
        path.addLine(to: CGPoint(x: box.minX + radius, y: box.maxY))
        path.addArc(center: CGPoint(x: box.minX + radius, y: box.midY), radius: radius, startAngle: .degrees(SheetValues.quarterTurn), endAngle: .degrees(SheetValues.halfTurn + SheetValues.quarterTurn), clockwise: false)
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> Pill {
        Pill(inset: inset + amount)
    }
}

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

extension View {
    func ring<S: InsettableShape>(_ shape: S, _ color: Color?) -> some View {
        overlay(shape.strokeBorder(color ?? .clear, lineWidth: CGFloat(Tokens.Size.hairline)))
    }
}
