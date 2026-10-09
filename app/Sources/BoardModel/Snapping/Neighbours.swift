import Foundation
import ALFAcolorCore

/// A measured gap from a rectangle to its nearest neighbour in one direction, with the spacing stop
/// nearest to the gap.
public struct SnapDistance: Equatable, Sendable {
    /// The gap as a line: from the neighbour to the rectangle. `value` is the gap in board points.
    public var measure: Measure
    /// The stop nearest to the gap. nil when no spacing stops are given.
    public var nearest: SpacingStop?

    public init(measure: Measure, nearest: SpacingStop?) {
        self.measure = measure
        self.nearest = nearest
    }

    /// The gap minus the value of the nearest stop. 0 on a stop, -1 for a gap of 15 next to a stop of 16.
    public var deviation: Double? { nearest.map { measure.value - $0.value } }
}

/// Measures the gaps from a rectangle to its nearest neighbour above, below, left and right.
enum Neighbours {
    private enum Direction: Int, CaseIterable {
        case left, right, up, down
    }

    private struct Gap {
        var value: Double
        var other: Rect
    }

    /// The distances in the order left, right, up, down. A direction without a neighbour gives nothing.
    /// A neighbour counts for left and right when it shares some height with the rectangle, and for up
    /// and down when it shares some width. `stops` must be sorted by value.
    static func distances(of rect: Rect, among others: [Rect], stops: [SpacingStop]) -> [SnapDistance] {
        guard rect.isFinite else { return [] }
        var best = [Gap?](repeating: nil, count: Direction.allCases.count)
        for other in others where other.isFinite {
            if other.y < rect.maxY && other.maxY > rect.y {
                if other.maxX <= rect.x { keepSmaller(&best[Direction.left.rawValue], rect.x - other.maxX, other) }
                if other.x >= rect.maxX { keepSmaller(&best[Direction.right.rawValue], other.x - rect.maxX, other) }
            }
            if other.x < rect.maxX && other.maxX > rect.x {
                if other.maxY <= rect.y { keepSmaller(&best[Direction.up.rawValue], rect.y - other.maxY, other) }
                if other.y >= rect.maxY { keepSmaller(&best[Direction.down.rawValue], other.y - rect.maxY, other) }
            }
        }
        return Direction.allCases.compactMap { direction in
            guard let gap = best[direction.rawValue] else { return nil }
            return SnapDistance(measure: measure(direction, from: gap.other, to: rect, value: gap.value),
                                nearest: nearestStop(to: gap.value, in: stops))
        }
    }

    private static func keepSmaller(_ slot: inout Gap?, _ value: Double, _ other: Rect) {
        if let current = slot, current.value <= value { return }
        slot = Gap(value: value, other: other)
    }

    private static func measure(_ direction: Direction, from other: Rect, to rect: Rect, value: Double) -> Measure {
        switch direction {
        case .left, .right:
            let y = middle(rect.y, rect.maxY, other.y, other.maxY)
            let start = direction == .left ? other.maxX : rect.maxX
            let end = direction == .left ? rect.x : other.x
            return Measure(fromX: start, fromY: y, toX: end, toY: y, value: value)
        case .up, .down:
            let x = middle(rect.x, rect.maxX, other.x, other.maxX)
            let start = direction == .up ? other.maxY : rect.maxY
            let end = direction == .up ? rect.y : other.y
            return Measure(fromX: x, fromY: start, toX: x, toY: end, value: value)
        }
    }

    /// The middle of the part that two ranges share.
    private static func middle(_ aLower: Double, _ aUpper: Double, _ bLower: Double, _ bUpper: Double) -> Double {
        (max(aLower, bLower) + min(aUpper, bUpper)) / 2
    }

    /// The stop nearest to a value. `stops` must be sorted by value. nil for no stops.
    static func nearestStop(to value: Double, in stops: [SpacingStop]) -> SpacingStop? {
        var low = 0, high = stops.count
        while low < high {
            let middle = (low + high) / 2
            if stops[middle].value < value { low = middle + 1 } else { high = middle }
        }
        // `low` is the first stop that is not below the value; the nearest one is it or the stop before it.
        let above = low < stops.count ? stops[low] : nil
        let below = low > 0 ? stops[low - 1] : nil
        guard let above else { return below }
        guard let below else { return above }
        return abs(below.value - value) <= abs(above.value - value) ? below : above
    }
}
