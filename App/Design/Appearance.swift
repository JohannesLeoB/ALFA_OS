import Core
import Design
import SwiftUI

struct Appearance: Equatable {
    let dark: Bool
    let still: Bool
    let bundle: Bundle

    init(dark: Bool, still: Bool, bundle: Bundle = .main) {
        self.dark = dark
        self.still = still
        self.bundle = bundle
    }

    var colors: Colors { dark ? .dark : .light }

    var shadows: Shadows { dark ? .dark : .light }

    var moods: Moods { dark ? .dark : .light }

    func paint(_ value: ColorValue) -> Color {
        Color(.sRGB, red: value.red, green: value.green, blue: value.blue, opacity: value.alpha)
    }

    func color(_ key: KeyPath<Colors, ColorValue>) -> Color {
        paint(colors[keyPath: key])
    }

    func mood(_ key: KeyPath<Moods, ColorValue>) -> Color {
        paint(moods[keyPath: key])
    }

    func ease(_ seconds: Double, _ curve: CubicBezier = Tokens.Easing.standard, delay: Double = 0) -> Animation? {
        still ? nil : Animation.timingCurve(curve.x1, curve.y1, curve.x2, curve.y2, duration: seconds).delay(delay)
    }

    func ease(_ timing: Timing) -> Animation? {
        ease(timing.duration, timing.easing, delay: timing.delay)
    }

    var locale: Locale {
        guard let language = bundle.preferredLocalizations.first else { return .current }
        let chosen = Locale(identifier: language)
        return Locale.current.language.languageCode == chosen.language.languageCode ? .current : chosen
    }

    func text(_ key: String) -> Text {
        Text(LocalizedStringKey(key), bundle: bundle)
    }

    func string(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), bundle: bundle)
    }

    func format(_ key: String, _ arguments: CVarArg...) -> String {
        let text = string(key)
        guard text.range(of: #"\{\d+\}"#, options: .regularExpression) != nil else {
            return String(format: text, arguments: arguments)
        }
        return PlaceholderEngine.fill(text, arguments.map { String(describing: $0) })
    }
}
