import Foundation
import Tokens

/// WCAG level of one contrast cell.
public enum ContrastLevel: Sendable, Equatable {
    case aaa, aa, insufficient
}

/// One cell of the contrast matrix: the ratio of a text colour on a ground, and its level.
public struct ContrastCell: Equatable, Sendable {
    public var ratio: Double
    public var level: ContrastLevel

    public init(ratio: Double, level: ContrastLevel) {
        self.ratio = ratio
        self.level = level
    }
}

/// Contrast of text colours on grounds. Rows are the texts, columns the grounds.
public enum ContrastMatrix {
    /// The level of a ratio. Normal text: AAA from 7, AA from 4.5. Large text: AAA from 4.5, AA from 3.
    public static func level(_ ratio: Double, largeText: Bool = false) -> ContrastLevel {
        if largeText { return ratio >= 4.5 ? .aaa : ratio >= 3 ? .aa : .insufficient }
        return ratio >= 7 ? .aaa : ratio >= 4.5 ? .aa : .insufficient
    }

    /// The colour of the page under a ground: a translucent ground is mixed over white.
    public static func page(_ ground: RGB) -> RGB {
        ground.a < 1 ? mix(ground, over: RGB(r: 1, g: 1, b: 1)) : ground
    }

    /// The text as it shows on the ground: its alpha mixes it over the page colour.
    public static func shown(text: RGB, over ground: RGB) -> RGB {
        mix(text, over: page(ground))
    }

    /// One cell. The ratio compares the shown text with the page under the ground.
    public static func cell(text: RGB, ground: RGB, largeText: Bool = false) -> ContrastCell {
        let ratio = ColorMath.contrast(shown(text: text, over: ground), page(ground))
        return ContrastCell(ratio: ratio, level: level(ratio, largeText: largeText))
    }

    /// The whole matrix: one row per text, one cell per ground.
    public static func grid(texts: [RGB], grounds: [RGB], largeText: Bool = false) -> [[ContrastCell]] {
        texts.map { text in grounds.map { cell(text: text, ground: $0, largeText: largeText) } }
    }

    /// Mixes a colour over another one by the alpha of the top colour. The result is opaque.
    static func mix(_ top: RGB, over bottom: RGB) -> RGB {
        let a = top.a
        return RGB(r: top.r * a + bottom.r * (1 - a), g: top.g * a + bottom.g * (1 - a), b: top.b * a + bottom.b * (1 - a))
    }
}
