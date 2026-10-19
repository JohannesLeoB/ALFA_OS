import AppKit
import CoreText
import ShellCore
import SwiftUI

struct Theme {
    let geometry: ShellGeometry
    let dark: Bool
    let still: Bool
    let bundle: Bundle

    func design(_ key: KeyPath<DesignColors, RGB>) -> Color {
        DesignStyle(dark: dark).color(key)
    }

    func mood(_ key: KeyPath<DesignMoods, RGB>) -> Color {
        color((dark ? DesignMoods.dark : DesignMoods.light)[keyPath: key])
    }

    func color(_ rgb: RGB) -> Color {
        Color(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: rgb.alpha)
    }

    func designShadow(_ key: KeyPath<DesignShadows, [ShadowLayer]>) -> [ShadowLayer] {
        (dark ? DesignShadows.dark : DesignShadows.light)[keyPath: key]
    }

    func font(_ size: Double = Design.TextSize.body, weight: Int = Design.Weight.regular) -> Font {
        Font(Typeface.font(size: size, weight: weight))
    }

    func ease(_ seconds: Double, _ curve: CubicBezier = Design.Easing.standard, delay: Double = 0) -> Animation? {
        still ? nil : Animation.timingCurve(curve.x1, curve.y1, curve.x2, curve.y2, duration: seconds).delay(delay)
    }

    func text(_ key: String) -> Text {
        Text(LocalizedStringKey(key), bundle: bundle)
    }

    func string(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), bundle: bundle)
    }
}

enum Typeface {
    private final class Anchor {}

    private static let ready: Bool = {
        guard let url = Bundle(for: Anchor.self).url(forResource: "Geist-VariableFont_wght", withExtension: "ttf") else { return false }
        return CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }()

    private static let weightAxis = 0x7767_6874

    static func font(size: Double, weight: Int) -> NSFont {
        _ = ready
        let size = CGFloat(size)
        if let family = Design.Family.text.first {
            let variation = NSFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String)
            let descriptor = NSFontDescriptor(fontAttributes: [.family: family, variation: [weightAxis: weight]])
            if let font = NSFont(descriptor: descriptor, size: size), font.familyName == family { return font }
        }
        return NSFont.systemFont(ofSize: size, weight: systemWeight(weight))
    }

    static func font(size: Double, weight: Font.Weight) -> NSFont {
        let value: Int
        switch weight {
        case .light: value = Design.Weight.light
        case .medium: value = Design.Weight.medium
        case .semibold: value = Design.Weight.semibold
        default: value = Design.Weight.regular
        }
        return font(size: size, weight: value)
    }

    static func leading(size: Double, weight: Int) -> CGFloat {
        let face = font(size: size, weight: weight)
        let natural = face.ascender - face.descender + face.leading
        return max(0, CGFloat(size * Design.LineHeight.body) - natural)
    }

    static func width(_ text: String, size: Double, weight: Int) -> Double {
        Double((text as NSString).size(withAttributes: [.font: font(size: size, weight: weight)]).width)
    }

    private static func systemWeight(_ value: Int) -> NSFont.Weight {
        switch value {
        case ..<Design.Weight.regular: .light
        case ..<Design.Weight.medium: .regular
        case ..<Design.Weight.semibold: .medium
        default: .semibold
        }
    }
}

struct ThemeShadow<S: InsettableShape>: ViewModifier {
    let theme: Theme
    let layers: [ShadowLayer]
    let shape: S

    func body(content: Content) -> some View {
        let layers = layers.filter { !$0.inset }
        return layers.reduce(AnyView(content)) { view, layer in
            if layer.isContour {
                let width = CGFloat(layer.spread)
                return AnyView(view.background(
                    shape.fill(theme.color(layer.color)).padding(-width)
                ))
            }
            return AnyView(view.shadow(
                color: theme.color(layer.color),
                radius: CGFloat(layer.blur / 2),
                x: CGFloat(layer.x),
                y: CGFloat(layer.y)
            ))
        }
    }
}

extension View {
    func themeShadow<S: InsettableShape>(_ theme: Theme, layers: [ShadowLayer], shape: S) -> some View {
        modifier(ThemeShadow(theme: theme, layers: layers, shape: shape))
    }
}
