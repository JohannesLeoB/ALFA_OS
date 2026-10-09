import Foundation
import Tokens

/// Suggests a text colour for a ground that reaches a contrast ratio. The lightness changes in Lab;
/// the hue angle stays exact. Only where sRGB cannot show the colour, the chroma drops by the least that fits.
public enum ContrastSuggestion {
    /// The colour with the smallest lightness change that reaches `target` on the ground.
    /// Returns nil when the text already reaches it. Both colours are opaque; a translucent ground is mixed over white.
    public static func text(_ text: RGB, on ground: RGB, target: Double = 4.5) -> RGB? {
        let page = ContrastMatrix.page(ground)
        guard ColorMath.contrast(text, page) < target else { return nil }
        let start = ColorMath.lab(text)
        func color(_ lightness: Double) -> RGB {
            ColorMath.rgb(fit(Lab(l: lightness, a: start.a, b: start.b)))
        }
        func reaches(_ lightness: Double) -> Bool {
            ColorMath.contrast(color(lightness), page) >= target
        }
        // Moves the lightness from the start toward `end` and returns the first lightness that reaches the target.
        // nil when the end itself does not reach it.
        func boundary(toward end: Double) -> Double? {
            guard reaches(end) else { return nil }
            var failing = start.l
            var passing = end
            for _ in 0..<60 {
                let middle = (failing + passing) / 2
                if reaches(middle) { passing = middle } else { failing = middle }
            }
            return passing
        }
        // The smaller move wins. A move through the ground's own lightness is always longer,
        // so the smaller move also goes toward the better contrast.
        let options = [boundary(toward: 0), boundary(toward: 100)].compactMap { $0 }
        guard let best = options.min(by: { abs($0 - start.l) < abs($1 - start.l) }) else { return nil }
        return color(best)
    }

    /// The Lab colour itself when sRGB shows it; otherwise the same hue at the largest chroma that fits.
    /// Found by bisection on the chroma factor (0 is grey, which fits at every lightness).
    static func fit(_ p: Lab) -> Lab {
        guard !shows(p) else { return p }
        var low = 0.0, high = 1.0
        for _ in 0..<40 {
            let middle = (low + high) / 2
            if shows(Lab(l: p.l, a: p.a * middle, b: p.b * middle)) { low = middle } else { high = middle }
        }
        return Lab(l: p.l, a: p.a * low, b: p.b * low)
    }

    /// True when the colour lies inside sRGB: converting it to RGB and back changes nothing.
    static func shows(_ p: Lab) -> Bool {
        let back = ColorMath.lab(ColorMath.rgb(p))
        return abs(back.l - p.l) < 0.05 && abs(back.a - p.a) < 0.05 && abs(back.b - p.b) < 0.05
    }
}
