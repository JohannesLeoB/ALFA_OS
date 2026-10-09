import Foundation

/// A scroll event of the trackpad or the mouse wheel, as the canvas gets it.
public struct ScrollInput: Equatable, Sendable {
    /// The distance of the content on the canvas. A positive value moves the content right or down.
    public var deltaX: Double
    public var deltaY: Double
    /// True for a trackpad or a Magic Mouse, whose distances are points. A wheel reports lines.
    public var isPrecise: Bool
    /// True while the zoom key is held: the scroll zooms and does not move.
    public var zooms: Bool
    /// The pointer on the canvas.
    public var x: Double
    public var y: Double

    public init(deltaX: Double, deltaY: Double, isPrecise: Bool, zooms: Bool, x: Double, y: Double) {
        self.deltaX = deltaX; self.deltaY = deltaY; self.isPrecise = isPrecise; self.zooms = zooms; self.x = x; self.y = y
    }

    /// Points for one line of a wheel.
    public static let lineHeight = 10.0
    /// Zoom per point of scroll: a distance of `1 / zoomSensitivity` points changes the zoom by the factor e.
    public static let zoomSensitivity = 0.01
    /// One event never changes the zoom by more than this factor, up or down.
    public static let largestFactor = 1.5

    var pointsX: Double { isPrecise ? deltaX : deltaX * Self.lineHeight }
    var pointsY: Double { isPrecise ? deltaY : deltaY * Self.lineHeight }
}

public extension Viewport {
    /// The view after a scroll event. Scrolling moves the content with the fingers. With the zoom key held,
    /// scrolling up zooms in around the pointer.
    func scrolled(by input: ScrollInput) -> Viewport {
        guard isValid, input.pointsX.isFinite, input.pointsY.isFinite, input.x.isFinite, input.y.isFinite else { return self }
        if input.zooms {
            let raw = exp(input.pointsY * ScrollInput.zoomSensitivity)
            let factor = min(max(raw, 1 / ScrollInput.largestFactor), ScrollInput.largestFactor)
            return zoomed(by: factor, aroundCanvasX: input.x, y: input.y)
        }
        return panned(byCanvasX: input.pointsX, y: input.pointsY)
    }
}
