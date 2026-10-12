import CoreGraphics

/// The outline of a rounded rectangle, for the trail that runs round a picked item.
public enum TrailOutline {
    /// Closed path of a rounded rectangle. It starts at the top edge, after the corner, and runs clockwise on screen.
    /// A radius of infinity gives a circle or a pill, since the radius is cut to half of each side.
    public static func path(width: CGFloat, height: CGFloat, radius: CGFloat) -> CGPath {
        let r = max(0, min(radius, width / 2, height / 2))
        let path = CGMutablePath()
        path.move(to: CGPoint(x: r, y: 0))
        path.addLine(to: CGPoint(x: width - r, y: 0))
        path.addArc(center: CGPoint(x: width - r, y: r), radius: r,
                    startAngle: -.pi / 2, endAngle: 0, clockwise: false, transform: .identity)
        path.addLine(to: CGPoint(x: width, y: height - r))
        path.addArc(center: CGPoint(x: width - r, y: height - r), radius: r,
                    startAngle: 0, endAngle: .pi / 2, clockwise: false, transform: .identity)
        path.addLine(to: CGPoint(x: r, y: height))
        path.addArc(center: CGPoint(x: r, y: height - r), radius: r,
                    startAngle: .pi / 2, endAngle: .pi, clockwise: false, transform: .identity)
        path.addLine(to: CGPoint(x: 0, y: r))
        path.addArc(center: CGPoint(x: r, y: r), radius: r,
                    startAngle: .pi, endAngle: 3 * .pi / 2, clockwise: false, transform: .identity)
        path.closeSubpath()
        return path
    }
}

/// The lit part of a trail that runs once round an outline.
public enum TrailWindow {
    /// Length of the lit part, as a share of the whole outline.
    public static let length = 0.22

    /// The share of the outline that is lit at a progress from 0 to 1 + length, or nil when nothing is lit.
    /// The lit part leads the progress and its tail follows, so it leaves the outline at the end.
    public static func range(progress: Double, length: Double = TrailWindow.length) -> ClosedRange<Double>? {
        let head = min(max(progress, 0), 1 + length)
        let end = min(head, 1)
        let start = max(head - length, 0)
        guard end > start else { return nil }
        return start...end
    }
}
