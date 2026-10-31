import Design
import Foundation

enum SignInStyle {
    static var css: String {
        let shared = shared()
        return fontFace + ":root{\(shared)\(variables(Colors.light, Shadows.light))}"
            + "@media (prefers-color-scheme:dark){:root{\(variables(Colors.dark, Shadows.dark))}}"
    }

    private final class Anchor {}

    private static var fontFace: String {
        guard let family = Tokens.Family.text.first,
              let url = Bundle(for: Anchor.self).url(forResource: "Geist-VariableFont_wght", withExtension: "ttf"),
              let data = try? Data(contentsOf: url) else { return "" }
        return "@font-face{font-family:\(family);font-weight:\(Tokens.Weight.light) \(Tokens.Weight.semibold);"
            + "src:url(data:font/ttf;base64,\(data.base64EncodedString())) format(\"truetype\")}"
    }

    private static func shared() -> String {
        let sizeEntries: [(String, Double)] = [
            ("size-blobHeight", Tokens.Size.blobHeight), ("size-blobWidth", Tokens.Size.blobWidth),
            ("size-blobAwakeWidth", Tokens.Size.blobAwakeWidth), ("size-blobEyeWidth", Tokens.Size.blobEyeWidth),
            ("size-blobEyeHeight", Tokens.Size.blobEyeHeight), ("size-blobEyeGap", Tokens.Size.blobEyeGap),
            ("size-hairline", Tokens.Size.hairline), ("size-blobLidOffset", Tokens.Size.blobLidOffset),
            ("size-blobEyeFollowDistance", Tokens.Size.blobEyeFollowDistance), ("size-blobEyeFollowRamp", Tokens.Size.blobEyeFollowRamp),
            ("size-blobEyeTravelX", Tokens.Size.blobEyeTravelX), ("size-blobEyeTravelY", Tokens.Size.blobEyeTravelY), ("size-selectionRingWidth", Tokens.Size.selectionRingWidth), ("size-confirmEnterBlur", Tokens.Size.confirmEnterBlur),
            ("radius-blob", Tokens.Radius.blob), ("radius-stroke", Tokens.Radius.stroke),
            ("spacing-step8", Tokens.Spacing.step8), ("spacing-step24", Tokens.Spacing.step24),
            ("spacing-step28", Tokens.Spacing.step28), ("spacing-step40", Tokens.Spacing.step40),
            ("spacing-blobInset", Tokens.Spacing.blobInset),
            ("typography-size-small", Tokens.TextSize.small), ("typography-size-body", Tokens.TextSize.body),
            ("typography-size-title", Tokens.TextSize.title),
        ]
        let sizes = sizeEntries.map { name, value in "--\(name):\(number(value))px;" }
        let plainEntries: [(String, String)] = [
            ("typography-weight-regular", String(Tokens.Weight.regular)),
            ("typography-weight-medium", String(Tokens.Weight.medium)),
            ("typography-lineHeight-title", number(Tokens.LineHeight.title)),
            ("typography-lineHeight-body", number(Tokens.LineHeight.body)),
            ("typography-tracking-title", number(Tokens.Tracking.title) + "em"),
            ("typography-family-text", Tokens.Family.text.map { $0.contains(" ") ? "\"\($0)\"" : $0 }.joined(separator: ",")),
            ("motion-easing-standard", bezier(Tokens.Easing.standard)),
            ("motion-easing-blobFlight", bezier(Tokens.Easing.blobFlight)),
            ("motion-duration-blobFlight", seconds(Tokens.Duration.blobFlight)),
            ("motion-duration-blobWidth", seconds(Tokens.Duration.blobWidth)),
            ("motion-duration-blobBlinkClose", seconds(Tokens.Duration.blobBlinkClose)),
            ("motion-duration-blobEyes", seconds(Tokens.Duration.blobEyes)),
            ("motion-duration-toggle", seconds(Tokens.Duration.toggle)),
            ("motion-duration-chevron", seconds(Tokens.Duration.chevron)),
            ("motion-duration-overviewEnter", seconds(Tokens.Duration.overviewEnter)),
        ]
        let plain = plainEntries.map { name, value in "--\(name):\(value);" }
        return (sizes + plain).joined()
    }

    private static func variables(_ colors: Colors, _ shadows: Shadows) -> String {
        let entries: [(String, String)] = [
            ("c-ground", color(colors.ground)), ("c-ink", color(colors.ink)),
            ("c-ink-2", color(colors.inkSecondary)), ("c-inv", color(colors.inverse)),
            ("c-on-inv", color(colors.onInverse)), ("sh-float", shadow(shadows.floating)),
        ]
        return entries.map { name, value in "--\(name):\(value);" }.joined()
    }

    private static func number(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }

    private static func seconds(_ value: Double) -> String {
        number(value) + "s"
    }

    private static func bezier(_ curve: CubicBezier) -> String {
        "cubic-bezier(\(number(curve.x1)),\(number(curve.y1)),\(number(curve.x2)),\(number(curve.y2)))"
    }

    private static func color(_ value: ColorValue) -> String {
        "color(srgb \(number(value.red)) \(number(value.green)) \(number(value.blue)) / \(number(value.alpha)))"
    }

    private static func shadow(_ layers: [ShadowLayer]) -> String {
        layers.map { layer in
            let parts = [layer.x, layer.y, layer.blur, layer.spread].map { number($0) + "px" }
            return (layer.inset ? "inset " : "") + parts.joined(separator: " ") + " " + color(layer.color)
        }.joined(separator: ",")
    }
}
