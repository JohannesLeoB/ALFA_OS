import Foundation
import ALFAcolorCore

/// The eight handles around a selection. A handle sits at a corner or at the middle of a side.
public enum ResizeHandle: CaseIterable, Sendable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left

    public var isCorner: Bool {
        switch self {
        case .topLeft, .topRight, .bottomRight, .bottomLeft: true
        case .top, .right, .bottom, .left: false
        }
    }

    /// The edge that moves on the x axis, nil when the handle keeps the left and right edge.
    public var xEdge: SnapEdge? {
        switch self {
        case .topLeft, .left, .bottomLeft: .lower
        case .topRight, .right, .bottomRight: .upper
        case .top, .bottom: nil
        }
    }

    /// The edge that moves on the y axis, nil when the handle keeps the top and bottom edge.
    public var yEdge: SnapEdge? {
        switch self {
        case .topLeft, .top, .topRight: .lower
        case .bottomLeft, .bottom, .bottomRight: .upper
        case .left, .right: nil
        }
    }

    /// Where the handle sits on the rectangle, 0 for the left or top edge, 0.5 for the middle, 1 for the right or bottom edge.
    var fractions: (x: Double, y: Double) {
        (xEdge == .lower ? 0 : xEdge == .upper ? 1 : 0.5, yEdge == .lower ? 0 : yEdge == .upper ? 1 : 0.5)
    }
}

/// Where the handles of a rectangle on the screen are, and which one a point hits. All numbers are screen points.
public enum HandleLayout {
    /// How far outside a handle the pointer still hits it.
    public static let hitSlop = 2.0

    /// The center of a handle on the rectangle.
    public static func position(of handle: ResizeHandle, in rect: Rect) -> (x: Double, y: Double) {
        let f = handle.fractions
        return (rect.x + f.x * rect.w, rect.y + f.y * rect.h)
    }

    /// The handles to show. The four corners are always there. A handle at the middle of a side needs room for
    /// itself and a gap on both sides, so a small rectangle shows only its corners.
    public static func visible(in rect: Rect, handleSize: Double) -> [ResizeHandle] {
        guard rect.isFinite, handleSize.isFinite, handleSize > 0 else { return [] }
        let room = 3 * handleSize
        return ResizeHandle.allCases.filter { handle in
            if handle.isCorner { return true }
            return handle.xEdge == nil ? rect.w >= room : rect.h >= room
        }
    }

    /// The handle under a point, or nil. A corner wins over a handle next to it.
    public static func hit(atX x: Double, y: Double, in rect: Rect, handleSize: Double) -> ResizeHandle? {
        guard x.isFinite, y.isFinite else { return nil }
        let reach = handleSize / 2 + hitSlop
        let shown = visible(in: rect, handleSize: handleSize)
        let ordered = shown.filter(\.isCorner) + shown.filter { !$0.isCorner }
        return ordered.first { handle in
            let p = position(of: handle, in: rect)
            return abs(p.x - x) <= reach && abs(p.y - y) <= reach
        }
    }
}

/// The arithmetic of a resize on the board.
public enum ResizeMath {
    /// No side of a resized rectangle gets shorter than this, in board points. A side that was shorter keeps its length as the least.
    public static let minimumSide = 8.0

    /// The rectangle after the pointer moved a handle by a distance. The opposite edges stay.
    /// A side does not shrink below the least length, so the rectangle never turns inside out.
    /// With `keepsRatio` the width and height stay in the ratio of the start: a corner scales along the larger change,
    /// a handle at a side scales the other axis around the middle. A rectangle without width or height ignores it.
    public static func resized(_ start: Rect, handle: ResizeHandle, dx: Double, dy: Double, keepsRatio: Bool) -> Rect {
        guard start.isFinite, dx.isFinite, dy.isFinite else { return start }
        let least = (w: min(minimumSide, start.w), h: min(minimumSide, start.h))
        var left = start.x, right = start.maxX, top = start.y, bottom = start.maxY
        switch handle.xEdge {
        case .lower?: left = min(start.x + dx, right - least.w)
        case .upper?: right = max(start.maxX + dx, left + least.w)
        case nil: break
        }
        switch handle.yEdge {
        case .lower?: top = min(start.y + dy, bottom - least.h)
        case .upper?: bottom = max(start.maxY + dy, top + least.h)
        case nil: break
        }
        var out = Rect(x: left, y: top, w: right - left, h: bottom - top)
        guard keepsRatio, start.w > 0, start.h > 0 else { return out }
        var scale: Double
        switch (handle.xEdge, handle.yEdge) {
        case (nil, _): scale = out.h / start.h
        case (_, nil): scale = out.w / start.w
        default: scale = max(out.w / start.w, out.h / start.h)
        }
        scale = max(scale, least.w / start.w, least.h / start.h)
        out.w = start.w * scale
        out.h = start.h * scale
        // The edge opposite the handle stays; an axis without a handle stays centered.
        switch handle.xEdge {
        case .lower?: out.x = start.maxX - out.w
        case .upper?: out.x = start.x
        case nil: out.x = start.center.x - out.w / 2
        }
        switch handle.yEdge {
        case .lower?: out.y = start.maxY - out.h
        case .upper?: out.y = start.y
        case nil: out.y = start.center.y - out.h / 2
        }
        return out
    }

    /// The rectangle of an item after its box changed from `old` to `new`: the item keeps its place and size relative to the box.
    /// An axis where the old box has no length moves with the new box and keeps its size.
    public static func mapped(_ rect: Rect, from old: Rect, to new: Rect) -> Rect {
        func axis(_ position: Double, _ length: Double, _ oldPosition: Double, _ oldLength: Double,
                  _ newPosition: Double, _ newLength: Double) -> (Double, Double) {
            guard oldLength > 0 else { return (newPosition + (position - oldPosition), length) }
            let scale = newLength / oldLength
            return (newPosition + (position - oldPosition) * scale, length * scale)
        }
        let x = axis(rect.x, rect.w, old.x, old.w, new.x, new.w)
        let y = axis(rect.y, rect.h, old.y, old.h, new.y, new.h)
        return Rect(x: x.0, y: y.0, w: x.1, h: y.1)
    }

    /// The smallest rectangle that holds all of them. nil for none.
    public static func bounds(of rects: some Sequence<Rect>) -> Rect? {
        var box: Rect?
        for rect in rects where rect.isFinite { box = box.map { $0.union(rect) } ?? rect }
        return box
    }
}
