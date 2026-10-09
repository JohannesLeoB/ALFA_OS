import Foundation

/// The view of one space: zoom and offset. It belongs to the user, not to the document.
/// The offset is the point of the board at the top left of the canvas, in points.
public struct Viewport: Equatable, Sendable {
    public var zoom: Double
    public var offsetX: Double
    public var offsetY: Double

    public init(zoom: Double = 1, offsetX: Double = 0, offsetY: Double = 0) {
        self.zoom = zoom; self.offsetX = offsetX; self.offsetY = offsetY
    }

    /// A view with a finite offset and a zoom above zero.
    public var isValid: Bool { zoom.isFinite && zoom > 0 && offsetX.isFinite && offsetY.isFinite }

    /// The point of the board that lies under a point of the canvas.
    public func boardPoint(canvasX: Double, canvasY: Double) -> (x: Double, y: Double) {
        (offsetX + canvasX / zoom, offsetY + canvasY / zoom)
    }

    /// The point of the canvas where a point of the board is drawn.
    public func canvasPoint(boardX: Double, boardY: Double) -> (x: Double, y: Double) {
        ((boardX - offsetX) * zoom, (boardY - offsetY) * zoom)
    }
}
