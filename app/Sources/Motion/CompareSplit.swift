import CoreGraphics

/// The divider of an image comparison. It holds the share of the width that the leading image covers.
public struct CompareSplit: Equatable, Sendable {
    /// Share of the width covered by the leading image, from 0 to 1.
    public private(set) var fraction: Double

    /// Change of the share for one key press, and for one key press with the large step.
    public static let step = 0.05
    public static let largeStep = 0.2

    public init(fraction: Double = 0.5) {
        self.fraction = CompareSplit.clamp(fraction)
    }

    public mutating func set(fraction value: Double) {
        fraction = CompareSplit.clamp(value)
    }

    public mutating func move(by delta: Double) {
        set(fraction: fraction + delta)
    }

    /// Share for a pointer at `x` in a view of the given width. A view without width keeps the middle.
    public static func fraction(atX x: CGFloat, width: CGFloat) -> Double {
        width > 0 ? clamp(Double(x / width)) : 0.5
    }

    static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

/// The spot of a spotlight over a grid. It follows the pointer and stays inside the view.
public enum Spotlight {
    /// Radius as a share of the longer side of the view.
    public static let radiusShare: CGFloat = 0.6

    /// Strength of the light, from 0 to 1.
    public static let strength = 0.16

    /// Centre in unit coordinates, from 0 to 1 both ways. Without a pointer the spot rests in the middle.
    public static func center(of pointer: CGPoint?, in size: CGSize) -> CGPoint {
        guard let pointer, size.width > 0, size.height > 0 else {
            return CGPoint(x: 0.5, y: 0.5)
        }
        return CGPoint(x: clamp(pointer.x / size.width), y: clamp(pointer.y / size.height))
    }

    /// Radius of the light in points.
    public static func radius(in size: CGSize) -> CGFloat {
        max(size.width, size.height) * radiusShare
    }

    private static func clamp(_ value: CGFloat) -> CGFloat {
        min(1, max(0, value))
    }
}
