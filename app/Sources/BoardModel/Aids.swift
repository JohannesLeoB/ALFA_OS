import Foundation
import ALFAcolorCore

/// A line that shows where a moving item snaps. Coordinates are board points.
public struct SnapGuide: Equatable, Sendable {
    public enum Axis: Equatable, Sendable {
        /// A line at a fixed x that runs up and down.
        case vertical
        /// A line at a fixed y that runs left and right.
        case horizontal
    }

    public var axis: Axis
    /// The x of a vertical line, the y of a horizontal line.
    public var position: Double
    /// The part of the line to draw, along its direction. nil draws it across the whole canvas.
    public var span: ClosedRange<Double>?

    public init(axis: Axis, position: Double, span: ClosedRange<Double>? = nil) {
        self.axis = axis; self.position = position; self.span = span
    }
}

/// A distance between two points of the board, with the value to show.
public struct Measure: Equatable, Sendable {
    public var fromX: Double, fromY: Double
    public var toX: Double, toY: Double
    public var value: Double

    public init(fromX: Double, fromY: Double, toX: Double, toY: Double, value: Double) {
        self.fromX = fromX; self.fromY = fromY; self.toX = toX; self.toY = toY; self.value = value
    }
}

/// A line on the canvas, in canvas points.
public struct CanvasSegment: Equatable, Sendable {
    public var fromX: Double, fromY: Double
    public var toX: Double, toY: Double

    public init(fromX: Double, fromY: Double, toX: Double, toY: Double) {
        self.fromX = fromX; self.fromY = fromY; self.toX = toX; self.toY = toY
    }
}

public extension SnapGuide {
    /// The line on the canvas. nil when the guide is not finite or lies outside the canvas.
    func segment(viewport: Viewport, canvas size: CanvasSize) -> CanvasSegment? {
        guard viewport.isValid, size.isUsable, position.isFinite else { return nil }
        switch axis {
        case .vertical:
            let x = (position - viewport.offsetX) * viewport.zoom
            guard x >= 0, x <= size.width else { return nil }
            let (top, bottom) = ends(from: viewport.offsetY, length: size.height, zoom: viewport.zoom)
            return CanvasSegment(fromX: x, fromY: top, toX: x, toY: bottom)
        case .horizontal:
            let y = (position - viewport.offsetY) * viewport.zoom
            guard y >= 0, y <= size.height else { return nil }
            let (left, right) = ends(from: viewport.offsetX, length: size.width, zoom: viewport.zoom)
            return CanvasSegment(fromX: left, fromY: y, toX: right, toY: y)
        }
    }

    private func ends(from offset: Double, length: Double, zoom: Double) -> (Double, Double) {
        guard let span, span.lowerBound.isFinite, span.upperBound.isFinite else { return (0, length) }
        return ((span.lowerBound - offset) * zoom, (span.upperBound - offset) * zoom)
    }
}

public extension Measure {
    /// The line on the canvas. nil when a number is not finite.
    func segment(viewport: Viewport) -> CanvasSegment? {
        guard viewport.isValid, [fromX, fromY, toX, toY].allSatisfy(\.isFinite) else { return nil }
        let start = viewport.canvasPoint(boardX: fromX, boardY: fromY)
        let end = viewport.canvasPoint(boardX: toX, boardY: toY)
        return CanvasSegment(fromX: start.x, fromY: start.y, toX: end.x, toY: end.y)
    }
}
