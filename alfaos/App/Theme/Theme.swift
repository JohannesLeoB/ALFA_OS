import AppKit
import ShellCore
import SwiftUI

struct Theme {
    let tokens: TokenTheme
    let geometry: ShellGeometry
    let metrics: ShellMetrics
    let mode: TokenMode
    let bundle: Bundle

    func color(_ key: ThemeKey) -> Color {
        let value = tokens.color(key, mode)
        var parts: [CGFloat] = [value.red, value.green, value.blue, value.alpha]
        return Color(nsColor: NSColor(colorSpace: .sRGB, components: &parts, count: parts.count))
    }

    func design(_ key: KeyPath<DesignColors, RGB>) -> Color {
        DesignStyle(dark: mode == .dark).color(key)
    }

    func pick(light: ThemeKey, dark: ThemeKey) -> Color {
        color(mode == .light ? light : dark)
    }

    func length(_ key: ThemeKey) -> CGFloat {
        CGFloat(tokens.length(key))
    }

    func measure(_ key: ShellMeasure) -> CGFloat {
        CGFloat(metrics.measure(key))
    }

    func font(_ key: TextKey) -> Font {
        guard let style = tokens.textStyle(key) else { return Font.body }
        let weight = Self.weight(style.weight)
        let size = CGFloat(style.size)
        let base = style.family == "mono"
            ? NSFont.monospacedSystemFont(ofSize: size, weight: weight)
            : NSFont.systemFont(ofSize: size, weight: weight)
        return Font(base)
    }

    func tracking(_ key: TextKey) -> CGFloat {
        CGFloat(tokens.textStyle(key)?.tracking ?? 0)
    }

    func animation(_ seconds: Double, _ curve: CubicBezier = Design.Easing.standard) -> Animation {
        Animation.timingCurve(curve.x1, curve.y1, curve.x2, curve.y2, duration: seconds)
    }

    func animation(_ duration: ThemeKey) -> Animation {
        let curve = tokens.curve(.motionCurveStandard)
        return Animation.timingCurve(curve.x1, curve.y1, curve.x2, curve.y2, duration: tokens.duration(duration))
    }

    func designShadow(_ key: KeyPath<DesignShadows, [ShadowLayer]>) -> [ShadowLayer] {
        (mode == .dark ? DesignShadows.dark : DesignShadows.light)[keyPath: key]
    }

    func shadows(_ key: ThemeKey) -> [ShadowLayer] {
        tokens.shadow(key, mode)
    }

    func color(_ rgb: RGB) -> Color {
        var parts: [CGFloat] = [rgb.red, rgb.green, rgb.blue, rgb.alpha]
        return Color(nsColor: NSColor(colorSpace: .sRGB, components: &parts, count: parts.count))
    }

    func text(_ key: String) -> Text {
        Text(LocalizedStringKey(key), bundle: bundle)
    }

    func string(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), bundle: bundle)
    }

    private static func weight(_ value: Int) -> NSFont.Weight {
        switch value {
        case ..<350: return .light
        case ..<450: return .regular
        case ..<550: return .medium
        case ..<650: return .semibold
        default: return .bold
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
                radius: CGFloat(layer.blur * theme.metrics.shadowBlurFactor),
                x: CGFloat(layer.x),
                y: CGFloat(layer.y)
            ))
        }
    }
}

extension View {
    func themeShadow<S: InsettableShape>(_ theme: Theme, _ key: ThemeKey, shape: S) -> some View {
        modifier(ThemeShadow(theme: theme, layers: theme.shadows(key), shape: shape))
    }

    func themeShadow<S: InsettableShape>(_ theme: Theme, layers: [ShadowLayer], shape: S) -> some View {
        modifier(ThemeShadow(theme: theme, layers: layers, shape: shape))
    }
}
