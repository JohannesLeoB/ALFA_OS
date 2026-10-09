import Foundation
import ALFAcolorCore

/// The reading of a measured line: its length in board points and its angle.
public struct MeasureReading: Equatable, Sendable {
    public var length: Double
    /// Degrees, counterclockwise as seen on the screen, from the horizontal to the right. In 0 ..< 360.
    public var angle: Double

    public init(length: Double, angle: Double) {
        self.length = length
        self.angle = angle
    }

    /// The reading of a line from its start to its end. nil when a coordinate is not finite.
    public static func of(_ line: Measure) -> MeasureReading? {
        let dx = line.toX - line.fromX, dy = line.toY - line.fromY
        guard dx.isFinite, dy.isFinite else { return nil }
        // The board's y runs down, so the sign flips to count counterclockwise on the screen.
        var degrees = atan2(-dy, dx) * 180 / Double.pi
        if degrees < 0 { degrees += 360 }
        return MeasureReading(length: hypot(dx, dy), angle: degrees)
    }
}

/// The end of a measured line snaps to the edges and middles of the items, through the snapping engine.
public enum MeasureSnap {
    /// The point that `x`, `y` snaps to. A point that is not near any edge stays as it is.
    public static func point(x: Double, y: Double, rects: [Rect], tolerance: Double, zoom: Double) -> (x: Double, y: Double) {
        let targets = SnapTargets(rects: rects)
        let result = Snapper.snap(Rect(x: x, y: y, w: 0, h: 0), motion: .move, targets: targets,
                                  tolerance: tolerance, zoom: zoom)
        return (result.rect.x, result.rect.y)
    }
}
