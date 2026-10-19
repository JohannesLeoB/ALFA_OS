import AppKit
import ShellCore
import SwiftUI

extension Font.Weight {
    static func design(_ value: Int) -> Font.Weight {
        switch value {
        case ..<350: .light
        case ..<450: .regular
        case ..<550: .medium
        case ..<650: .semibold
        default: .bold
        }
    }
}

struct InkSet {
    let primary: KeyPath<DesignColors, RGB>
    let secondary: KeyPath<DesignColors, RGB>
    let tertiary: KeyPath<DesignColors, RGB>
    let line: KeyPath<DesignColors, RGB>

    static var lane: InkSet { InkSet(primary: \.ink, secondary: \.inkSecondary, tertiary: \.inkTertiary, line: \.lineStrong) }
    static var inverse: InkSet { InkSet(primary: \.onInverse, secondary: \.onInverseSecondary, tertiary: \.onInverseTertiary, line: \.onInverseLine) }

    static func of(_ inverted: Bool) -> InkSet { inverted ? .inverse : .lane }
}

extension View {
    func ring<S: InsettableShape>(_ shape: S, _ color: Color?) -> some View {
        overlay(shape.strokeBorder(color ?? .clear, lineWidth: CGFloat(Design.Size.hairline)))
    }

    func lineHeight(_ height: Double, size: Double) -> some View {
        let font = NSFont.systemFont(ofSize: CGFloat(size))
        let natural = font.ascender - font.descender + font.leading
        let gap = max(0, CGFloat(height) - natural)
        return lineSpacing(gap).padding(.vertical, gap / 2)
    }

    func floatingShadow<S: InsettableShape>(_ shape: S) -> some View {
        modifier(FloatingShadow(shape: shape))
    }
}

private struct FloatingShadow<S: InsettableShape>: ViewModifier {
    @Environment(\.design) private var design
    let shape: S

    func body(content: Content) -> some View {
        let layers = (design.dark ? DesignShadows.dark : DesignShadows.light).floating.filter { !$0.inset }
        return layers.reduce(AnyView(content)) { view, layer in
            let color = Color(.sRGB, red: layer.color.red, green: layer.color.green, blue: layer.color.blue, opacity: layer.color.alpha)
            if layer.isContour {
                return AnyView(view.background(shape.fill(color).padding(-CGFloat(layer.spread))))
            }
            return AnyView(view.shadow(color: color, radius: CGFloat(layer.blur), x: CGFloat(layer.x), y: CGFloat(layer.y)))
        }
    }
}

struct ComponentMotion {
    let reduced: Bool

    func curve(_ duration: Double, _ easing: CubicBezier = Design.Easing.standard) -> Animation? {
        reduced ? nil : Animation.timingCurve(easing.x1, easing.y1, easing.x2, easing.y2, duration: duration)
    }
}
