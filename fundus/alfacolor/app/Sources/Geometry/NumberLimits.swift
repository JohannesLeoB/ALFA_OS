import Foundation
import ALFAcolorCore

/// Limits for numbers that come from input or from a file. A conversion from Double to Int traps for a value
/// beyond the Int range, and a size far beyond the board cannot be drawn, so both are cut at these values.
public enum NumberLimit {
    /// The largest size in points of a frame, a guide, a grid or a ruler step.
    public static let length: Double = 1_000_000
    /// The largest distance of a position from the origin of the board, in points.
    public static let coordinate: Double = 10_000_000
    /// The largest whole number that `Double.clampedInt` returns. Far below the Int range, so scale products stay exact.
    public static let integer: Double = 1_000_000_000_000_000
}

public extension Double {
    /// The value rounded to the nearest whole number and cut to `NumberLimit.integer`. Never traps.
    /// A value that is not finite gives 0.
    var clampedInt: Int {
        guard isFinite else { return 0 }
        return Int(Swift.min(Swift.max(rounded(), -NumberLimit.integer), NumberLimit.integer))
    }
}

/// A size in points: 0 for NaN and negative values, `NumberLimit.length` for values above it.
public func clampedLength(_ value: Double) -> Double {
    guard !value.isNaN else { return 0 }
    return Swift.min(Swift.max(value, 0), NumberLimit.length)
}

/// A position in points: 0 for NaN, and the value cut to `NumberLimit.coordinate` on both sides.
public func clampedCoordinate(_ value: Double) -> Double {
    guard !value.isNaN else { return 0 }
    return Swift.min(Swift.max(value, -NumberLimit.coordinate), NumberLimit.coordinate)
}

public extension Rect {
    /// The rectangle with its position and size cut to the number limits. A rectangle inside them is unchanged.
    var limited: Rect {
        Rect(x: clampedCoordinate(x), y: clampedCoordinate(y), w: clampedLength(w), h: clampedLength(h))
    }
}
