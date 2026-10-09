import Foundation

/// The aspect ratio of a size, reduced to whole numbers, and the known ratio nearest to it.
public struct AspectRatio: Equatable, Sendable {
    /// The reduced width and height. A ratio of 756:491 reads as `width` 756 and `height` 491.
    public let width: Int
    public let height: Int

    /// Nil when a side is not finite, not above zero, or too large to reduce.
    public init?(width w: Double, height h: Double) {
        guard w.isFinite, h.isFinite, w > 0, h > 0 else { return nil }
        // Scale up until both sides are whole numbers, at most three decimals: 756.5 x 491 reads as 1513:982.
        var scale = 1.0
        while scale < 1000, abs(w * scale - (w * scale).rounded()) > 1e-6 || abs(h * scale - (h * scale).rounded()) > 1e-6 {
            scale *= 10
        }
        let a = (w * scale).rounded(), b = (h * scale).rounded()
        guard a >= 1, b >= 1, a < 1e15, b < 1e15 else { return nil }
        let divisor = Self.gcd(Int(a), Int(b))
        width = Int(a) / divisor
        height = Int(b) / divisor
    }

    /// The ratio as text, width first: "756:491".
    public var text: String { "\(width):\(height)" }

    /// The known ratio nearest to this one. Orientation does not count: 2:3 is nearest to 3:2.
    public var nearest: Known {
        let ratio = Double(max(width, height)) / Double(min(width, height))
        return Known.allCases.min { abs(log($0.longerToShorter / ratio)) < abs(log($1.longerToShorter / ratio)) } ?? .square
    }

    /// The known ratios of the vision: 1:1, 3:2, 4:3, 16:9, DIN 1:√2 and the golden section.
    public enum Known: CaseIterable, Sendable {
        case square, threeToTwo, fourToThree, sixteenToNine, din, golden

        /// The longer side over the shorter one.
        var longerToShorter: Double {
            switch self {
            case .square: 1
            case .threeToTwo: 1.5
            case .fourToThree: 4.0 / 3.0
            case .sixteenToNine: 16.0 / 9.0
            case .din: 2.0.squareRoot()
            case .golden: (1.0 + 5.0.squareRoot()) / 2.0
            }
        }

        /// The key of the label in the string catalog, for example "ratio.threeToTwo".
        public var nameKey: String { "ratio.\(self)" }
    }

    private static func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }
}
