import Foundation
import ALFAcolorCore

/// Finds the item under a point of the board.
public enum HitTest {
    /// How far an outline or a line reaches, in screen points.
    public static let edgeReach = 4.0
    /// An item is at least this large for the pointer, in screen points.
    public static let minimumTarget = 8.0

    /// The topmost item under the point. `drawn` is in paint order, from back to front.
    /// A card, a shape and a text are hit anywhere inside; an ellipse inside its ellipse; a line near the line.
    /// A frame or group is hit on its band and on its outline only, so that the area inside stays free for a lasso.
    /// `bandHeight` is the height of that band in board points. `zoom` turns the screen reaches into board points.
    public static func item(atX x: Double, y: Double, among drawn: [Item], zoom: Double, bandHeight: Double) -> ItemID? {
        guard x.isFinite, y.isFinite, zoom.isFinite, zoom > 0 else { return nil }
        for item in drawn.reversed() where item.rect.isFinite && hits(item, x: x, y: y, zoom: zoom, bandHeight: bandHeight) {
            return item.id
        }
        return nil
    }

    static func hits(_ item: Item, x: Double, y: Double, zoom: Double, bandHeight: Double) -> Bool {
        let reach = edgeReach / zoom
        let rect = Self.target(item.rect, zoom: zoom)
        switch item.content {
        case .group, .frame:
            let band = CardLayout.band(size: CanvasSize(width: item.rect.w, height: item.rect.h), headerHeight: bandHeight)
            let top = Rect(x: item.rect.x, y: item.rect.y, w: band.w, h: band.h)
            if top.contains(x: x, y: y) { return true }
            let outer = Rect(x: rect.x - reach, y: rect.y - reach, w: rect.w + 2 * reach, h: rect.h + 2 * reach)
            let inner = Rect(x: rect.x + reach, y: rect.y + reach, w: rect.w - 2 * reach, h: rect.h - 2 * reach)
            return outer.contains(x: x, y: y) && !(inner.w > 0 && inner.h > 0 && inner.contains(x: x, y: y))
        case .shape(let kind, let style):
            switch kind {
            case .line:
                let width = style.strokeWidth.isFinite ? max(style.strokeWidth, 0) : 0
                return distanceToLine(x: x, y: y, from: item.rect) <= max(reach, width / 2)
            case .ellipse:
                return insideEllipse(x: x, y: y, in: rect)
            case .rectangle, .capsule:
                return rect.contains(x: x, y: y)
            }
        default:
            return rect.contains(x: x, y: y)
        }
    }

    /// The rectangle widened around its center to the smallest size that the pointer can still hit.
    static func target(_ rect: Rect, zoom: Double) -> Rect {
        let least = minimumTarget / zoom
        var out = rect
        if out.w < least { out.x -= (least - out.w) / 2; out.w = least }
        if out.h < least { out.y -= (least - out.h) / 2; out.h = least }
        return out
    }

    /// The distance from a point to the diagonal of a rectangle, from the top left to the bottom right corner.
    private static func distanceToLine(x: Double, y: Double, from rect: Rect) -> Double {
        let dx = rect.w, dy = rect.h
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return hypot(x - rect.x, y - rect.y) }
        let t = min(max(((x - rect.x) * dx + (y - rect.y) * dy) / lengthSquared, 0), 1)
        return hypot(x - (rect.x + t * dx), y - (rect.y + t * dy))
    }

    private static func insideEllipse(x: Double, y: Double, in rect: Rect) -> Bool {
        let radiusX = rect.w / 2, radiusY = rect.h / 2
        guard radiusX > 0, radiusY > 0 else { return false }
        let c = rect.center
        let u = (x - c.x) / radiusX, v = (y - c.y) / radiusY
        return u * u + v * v <= 1
    }
}

/// The lasso: a rectangle that the pointer draws on free space.
public enum Lasso {
    /// The rectangle between two points, whichever corner comes first.
    public static func rect(fromX ax: Double, y ay: Double, toX bx: Double, y by: Double) -> Rect {
        Rect(x: min(ax, bx), y: min(ay, by), w: abs(ax - bx), h: abs(ay - by))
    }

    /// The items the lasso takes. An item that is hidden, or on a hidden layer, is never taken.
    /// A frame or group is taken only when it lies completely inside; any other item when the lasso touches it.
    /// A lasso without width or height takes nothing.
    public static func hits(in lasso: Rect, space: Space) -> Set<ItemID> {
        guard lasso.isFinite, lasso.w > 0, lasso.h > 0 else { return [] }
        let hiddenLayers = Set(space.layers.filter { !$0.visible }.map(\.id))
        var taken = Set<ItemID>()
        for item in space.items where !item.hidden && !hiddenLayers.contains(item.layerID) && item.rect.isFinite {
            if item.isContainer ? encloses(lasso, item.rect) : lasso.intersects(item.rect) { taken.insert(item.id) }
        }
        return taken
    }

    private static func encloses(_ outer: Rect, _ inner: Rect) -> Bool {
        inner.x >= outer.x && inner.y >= outer.y && inner.maxX <= outer.maxX && inner.maxY <= outer.maxY
    }
}
