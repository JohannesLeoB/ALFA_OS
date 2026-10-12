import Foundation
import ALFAcolorCore

/// What the zoom commands of the menu do.
public enum ZoomAction: Equatable, Sendable {
    case zoomIn, zoomOut
    /// 100 percent.
    case actualSize
    /// All visible items of the space fit in the canvas.
    case fitAll
    /// The selected items fit in the canvas.
    case fitSelection
}

/// The size of the canvas in points.
public struct CanvasSize: Equatable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) { self.width = width; self.height = height }

    public static let zero = CanvasSize(width: 0, height: 0)

    /// A size with a finite width and height above zero.
    public var isUsable: Bool { width.isFinite && height.isFinite && width > 0 && height > 0 }
}

/// The calculations of the view. Every function returns a new view and leaves a view that cannot be
/// used (zoom of zero, value not finite) unchanged.
public extension Viewport {
    /// The part of the board that the canvas shows.
    func visibleRect(in size: CanvasSize) -> Rect {
        Rect(x: offsetX, y: offsetY, w: size.width / zoom, h: size.height / zoom)
    }

    /// A rectangle of the board as it is drawn on the canvas.
    func canvasRect(of rect: Rect) -> Rect {
        Rect(x: (rect.x - offsetX) * zoom, y: (rect.y - offsetY) * zoom, w: rect.w * zoom, h: rect.h * zoom)
    }

    /// The view after a zoom to `newZoom`. The board point under the canvas point stays where it is.
    func zoomed(to newZoom: Double, aroundCanvasX x: Double, y: Double) -> Viewport {
        guard isValid, newZoom.isFinite, x.isFinite, y.isFinite else { return self }
        let target = ZoomRange.clamped(newZoom)
        let anchor = boardPoint(canvasX: x, canvasY: y)
        return validated(Viewport(zoom: target, offsetX: anchor.x - x / target, offsetY: anchor.y - y / target))
    }

    /// The view after a zoom by a factor (above 1 zooms in), limited to the zoom range.
    func zoomed(by factor: Double, aroundCanvasX x: Double, y: Double) -> Viewport {
        guard factor.isFinite, factor > 0 else { return self }
        return zoomed(to: zoom * factor, aroundCanvasX: x, y: y)
    }

    /// The view after the content moved by a distance on the canvas.
    /// Content that moves right and down shows the part of the board at the top left.
    func panned(byCanvasX dx: Double, y dy: Double) -> Viewport {
        guard isValid, dx.isFinite, dy.isFinite else { return self }
        return validated(Viewport(zoom: zoom, offsetX: offsetX - dx / zoom, offsetY: offsetY - dy / zoom))
    }

    /// The view that shows a rectangle of the board in the middle of the canvas, with room around it.
    /// The zoom stays inside the zoom range. An empty rectangle keeps the zoom and only centers it.
    func fitting(_ rect: Rect, in size: CanvasSize, padding: Double = Viewport.fitPadding) -> Viewport {
        guard isValid, size.isUsable, rect.isFinite else { return self }
        let room = CanvasSize(width: max(size.width - 2 * padding, 1), height: max(size.height - 2 * padding, 1))
        let target: Double
        if rect.w > 0, rect.h > 0 {
            target = ZoomRange.clamped(min(room.width / rect.w, room.height / rect.h))
        } else {
            target = zoom
        }
        let center = rect.center
        return validated(Viewport(zoom: target, offsetX: center.x - size.width / 2 / target, offsetY: center.y - size.height / 2 / target))
    }

    /// The space around fitted content, in canvas points.
    static let fitPadding = 48.0

    /// The view after a zoom command. `all` is the box of the visible items, `selection` the box of the
    /// selected items. A fit without a box does nothing, except that "fit all" on an empty space resets the view.
    func applying(_ action: ZoomAction, canvas size: CanvasSize, all: Rect?, selection: Rect?) -> Viewport {
        guard isValid, size.isUsable else { return self }
        let centerX = size.width / 2, centerY = size.height / 2
        switch action {
        case .zoomIn: return zoomed(to: ZoomRange.stepUp(from: zoom), aroundCanvasX: centerX, y: centerY)
        case .zoomOut: return zoomed(to: ZoomRange.stepDown(from: zoom), aroundCanvasX: centerX, y: centerY)
        case .actualSize: return zoomed(to: 1, aroundCanvasX: centerX, y: centerY)
        case .fitAll: return all.map { fitting($0, in: size) } ?? Viewport()
        case .fitSelection: return selection.map { fitting($0, in: size) } ?? self
        }
    }

    private func validated(_ candidate: Viewport) -> Viewport { candidate.isValid ? candidate : self }
}

extension Rect {
    /// A rectangle with finite numbers and no negative size.
    var isFinite: Bool { x.isFinite && y.isFinite && w.isFinite && h.isFinite && w >= 0 && h >= 0 }

    /// The smallest rectangle that holds both.
    func union(_ other: Rect) -> Rect {
        let minX = min(x, other.x), minY = min(y, other.y)
        return Rect(x: minX, y: minY, w: max(maxX, other.maxX) - minX, h: max(maxY, other.maxY) - minY)
    }
}
