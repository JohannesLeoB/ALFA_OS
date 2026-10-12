import Foundation

/// The zoom limits of the canvas and the steps of the zoom in and zoom out commands.
public enum ZoomRange {
    /// 10 percent.
    public static let minimum = 0.1
    /// 800 percent.
    public static let maximum = 8.0
    /// The stops for zoom in and zoom out, ascending.
    public static let steps: [Double] = [0.1, 0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6, 8]

    /// The zoom inside the limits. A value that is not finite gives 1.
    public static func clamped(_ zoom: Double) -> Double {
        guard zoom.isFinite else { return 1 }
        return min(max(zoom, minimum), maximum)
    }

    /// The first stop above the zoom, or the maximum.
    public static func stepUp(from zoom: Double) -> Double {
        let current = clamped(zoom)
        return steps.first { $0 > current * (1 + tolerance) } ?? maximum
    }

    /// The last stop below the zoom, or the minimum.
    public static func stepDown(from zoom: Double) -> Double {
        let current = clamped(zoom)
        return steps.last { $0 < current * (1 - tolerance) } ?? minimum
    }

    /// The zoom as a whole percentage, for display.
    public static func percent(_ zoom: Double) -> Int {
        Int((clamped(zoom) * 100).rounded())
    }

    private static let tolerance = 1e-9
}
