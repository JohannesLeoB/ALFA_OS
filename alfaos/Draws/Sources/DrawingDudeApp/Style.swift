import AppKit
import CoreText
import DrawsFonts
import ShellCore
import SwiftUI

struct Style {
    let dark: Bool

    func color(_ key: KeyPath<DesignColors, RGB>) -> Color {
        let v = (dark ? DesignColors.dark : DesignColors.light)[keyPath: key]
        return Color(.sRGB, red: v.red, green: v.green, blue: v.blue, opacity: v.alpha)
    }

    func shadow(_ key: KeyPath<DesignShadows, [ShadowLayer]>) -> [ShadowLayer] {
        (dark ? DesignShadows.dark : DesignShadows.light)[keyPath: key]
    }

    func layerColor(_ rgb: RGB) -> Color {
        Color(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: rgb.alpha)
    }

    func font(_ size: Double = Design.TextSize.body, weight: Int = Design.Weight.regular) -> Font {
        Font(Face.font(size: size, weight: weight))
    }

    func ease(_ seconds: Double, _ curve: CubicBezier = Design.Easing.standard) -> Animation {
        .timingCurve(curve.x1, curve.y1, curve.x2, curve.y2, duration: seconds)
    }
}

enum Face {

    private static let weightAxis = 0x7767_6874

    static func font(size: Double, weight: Int) -> NSFont {
        DrawsFonts.register()
        if let family = Design.Family.text.first {
            let variation = NSFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String)
            let descriptor = NSFontDescriptor(fontAttributes: [.family: family, variation: [weightAxis: weight]])
            if let font = NSFont(descriptor: descriptor, size: CGFloat(size)), font.familyName == family { return font }
        }
        return NSFont.systemFont(ofSize: CGFloat(size), weight: weight >= Design.Weight.medium ? .medium : .regular)
    }
}

struct StyleKey: EnvironmentKey {
    static let defaultValue = Style(dark: false)
}

extension EnvironmentValues {
    var style: Style {
        get { self[StyleKey.self] }
        set { self[StyleKey.self] = newValue }
    }
}

func say(_ key: String) -> Text {
    Text(LocalizedStringKey(key), bundle: .module)
}

func word(_ key: String) -> String {
    String(localized: String.LocalizationValue(key), bundle: .module)
}

struct Shadowed<S: InsettableShape>: ViewModifier {
    let style: Style
    let layers: [ShadowLayer]
    let shape: S

    func body(content: Content) -> some View {
        layers.filter { !$0.inset }.reduce(AnyView(content)) { view, layer in
            if layer.isContour {
                return AnyView(view.background(shape.fill(style.layerColor(layer.color)).padding(-CGFloat(layer.spread))))
            }
            return AnyView(view.shadow(color: style.layerColor(layer.color), radius: CGFloat(layer.blur / 2),
                                       x: CGFloat(layer.x), y: CGFloat(layer.y)))
        }
    }
}

extension View {
    func shadowed<S: InsettableShape>(_ style: Style, _ layers: [ShadowLayer], _ shape: S) -> some View {
        modifier(Shadowed(style: style, layers: layers, shape: shape))
    }
}
