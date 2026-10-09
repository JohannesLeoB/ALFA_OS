import Foundation

/// The dots of the background grid that fall on the canvas.
public struct GridDots: Equatable, Sendable {
    /// Positions of the columns on the canvas, ascending.
    public var xs: [Double]
    /// Positions of the rows on the canvas, ascending.
    public var ys: [Double]
    /// The distance of the dots on the board, in points. A power of two times the base step.
    public var step: Double

    /// No dots are closer on the canvas than this.
    public static let minimumSpacing = 16.0
    /// A canvas never gets more dots than this per row or column.
    public static let maximumPerAxis = 200

    public static let empty = GridDots(xs: [], ys: [], step: 0)

    /// The dots for a view. When the grid would be too dense on the canvas, the step doubles until it is not.
    /// The dots stay on the board points that are multiples of the step.
    public static func make(viewport: Viewport, canvas size: CanvasSize, baseStep: Double = 8) -> GridDots {
        guard viewport.isValid, size.isUsable, baseStep.isFinite, baseStep > 0 else { return .empty }
        var step = baseStep
        while step * viewport.zoom < minimumSpacing
                || max(size.width, size.height) / (step * viewport.zoom) > Double(maximumPerAxis) {
            step *= 2
            if step > 1e12 { return .empty }
        }
        return GridDots(xs: positions(from: viewport.offsetX, length: size.width, step: step, zoom: viewport.zoom),
                        ys: positions(from: viewport.offsetY, length: size.height, step: step, zoom: viewport.zoom),
                        step: step)
    }

    private static func positions(from offset: Double, length: Double, step: Double, zoom: Double) -> [Double] {
        let first = (offset / step).rounded(.up)
        let last = ((offset + length / zoom) / step).rounded(.down)
        guard first.isFinite, last.isFinite, abs(first) < 1e15, abs(last) < 1e15, last >= first else { return [] }
        return (Int(first)...Int(last)).map { (Double($0) * step - offset) * zoom }
    }
}
