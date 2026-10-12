import Foundation
import ALFAcolorCore

/// The result of a snap: the rectangle after snapping, the lines to draw and the measured gaps.
public struct SnapResult: Equatable, Sendable {
    public var rect: Rect
    /// One line for each snapped position, with the span it runs over.
    public var guides: [SnapGuide]
    /// The gaps from the snapped rectangle to its nearest neighbours.
    public var distances: [SnapDistance]

    public init(rect: Rect, guides: [SnapGuide], distances: [SnapDistance]) {
        self.rect = rect
        self.guides = guides
        self.distances = distances
    }
}

/// Snaps a rectangle that moves or resizes. Pure logic: no SwiftUI and no state.
///
/// Each axis snaps on its own. Among the targets within reach the snapper takes the lowest kind
/// (see `SnapKind`), then the smallest distance. The lines show every snapped position that lies on
/// the chosen move.
public enum Snapper {
    /// Snaps `rect` to `targets`. `tolerance` is in screen points and `zoom` is the zoom of the view,
    /// so the reach on the board is `tolerance / zoom`. A tolerance or zoom that cannot be used turns
    /// the snapping off, but the distances are still measured. A rectangle that is not finite is returned unchanged.
    public static func snap(_ rect: Rect, motion: SnapMotion, targets: SnapTargets,
                            tolerance: Double, zoom: Double) -> SnapResult {
        guard rect.isFinite else { return SnapResult(rect: rect, guides: [], distances: []) }
        let stops = targets.spacing
            .filter { $0.value.isFinite && $0.value >= 0 }
            .sorted { $0.value < $1.value }
        var snapped = rect
        var guides: [SnapGuide] = []
        if let reach = reach(tolerance: tolerance, zoom: zoom) {
            let x = snapAxis(.x, of: rect, motion: motion, targets: targets, stops: stops, reach: reach)
            let y = snapAxis(.y, of: rect, motion: motion, targets: targets, stops: stops, reach: reach)
            apply(x.delta, along: .x, motion: motion, to: &snapped)
            apply(y.delta, along: .y, motion: motion, to: &snapped)
            // Lines run over the rectangle after both axes moved.
            guides = lines(of: x, along: .x, in: snapped) + lines(of: y, along: .y, in: snapped)
        }
        let distances = Neighbours.distances(of: snapped, among: targets.rects, stops: stops)
        return SnapResult(rect: snapped, guides: guides, distances: distances)
    }

    // MARK: One axis

    /// Two positions that are closer than this are the same position.
    private static let epsilon = 1e-9

    /// Where a line runs: a guide's own span (nil draws the whole canvas), or the moving rectangle
    /// joined with the item it snaps to (nil for the grid, which has no item).
    private enum LineSpan {
        case guide(ClosedRange<Double>?)
        case joined(ClosedRange<Double>?)
    }

    private struct AxisSnap {
        var delta: Double
        /// Every candidate that snaps to the chosen delta. Each one makes a line.
        var matches: [Candidate]
    }

    private struct Candidate {
        var kind: SnapKind
        var delta: Double
        var position: Double
        var span: LineSpan
    }

    private static func snapAxis(_ along: Along, of rect: Rect, motion: SnapMotion,
                                 targets: SnapTargets, stops: [SpacingStop], reach: Double) -> AxisSnap {
        let anchors = anchors(along, of: rect, motion: motion)
        guard !anchors.isEmpty else { return AxisSnap(delta: 0, matches: []) }
        let lineAxis: SnapGuide.Axis = along == .x ? .vertical : .horizontal
        var found: [Candidate] = []

        for anchor in anchors {
            for guide in targets.guides where guide.axis == lineAxis {
                consider(&found, .guide, anchor.value, guide.position, .guide(guide.span), reach)
            }
            for line in targets.frameLines where line.axis == lineAxis {
                consider(&found, .column, anchor.value, line.position, .guide(line.span), reach)
            }
            if targets.gridStep > 0, targets.gridStep.isFinite {
                let step = targets.gridStep
                let point = (anchor.value / step).rounded() * step
                consider(&found, .grid, anchor.value, point, .joined(nil), reach)
            }
        }

        let index = targets.index.axis(along)
        let largestStop = stops.last?.value ?? 0
        for anchor in anchors {
            let value = anchor.value
            // Edges and middles within reach.
            for position in index.edges.positions(from: value - reach, through: value + reach) {
                let other = targets.rects[index.edges.items[position]]
                consider(&found, .edge, value, index.edges.values[position], .joined(other.across(along)), reach)
            }
            // Spacing: the gap from the anchor to an item on its outer side, if it is near a stop.
            guard !stops.isEmpty else { continue }
            switch anchor.side {
            case .lower:
                for position in index.uppers.positions(from: value - largestStop - reach, through: value) {
                    let other = targets.rects[index.uppers.items[position]]
                    let upper = index.uppers.values[position]
                    guard sharesAcross(other, rect, along), let stop = Neighbours.nearestStop(to: value - upper, in: stops) else { continue }
                    consider(&found, .spacing, value, upper + stop.value, .joined(other.across(along)), reach)
                }
            case .upper:
                for position in index.lowers.positions(from: value, through: value + largestStop + reach) {
                    let other = targets.rects[index.lowers.items[position]]
                    let lower = index.lowers.values[position]
                    guard sharesAcross(other, rect, along), let stop = Neighbours.nearestStop(to: lower - value, in: stops) else { continue }
                    consider(&found, .spacing, value, lower - stop.value, .joined(other.across(along)), reach)
                }
            case .middle:
                break
            }
        }

        guard let best = found.min(by: ranksBefore) else { return AxisSnap(delta: 0, matches: []) }
        return AxisSnap(delta: best.delta, matches: found.filter { abs($0.delta - best.delta) <= epsilon })
    }

    /// The lines of one axis, drawn over the rectangle after the snap.
    private static func lines(of snap: AxisSnap, along: Along, in rect: Rect) -> [SnapGuide] {
        let axis: SnapGuide.Axis = along == .x ? .vertical : .horizontal
        let moved = rect.across(along)
        var lines: [SnapGuide] = []
        for match in snap.matches {
            let span: ClosedRange<Double>?
            switch match.span {
            case .guide(let own):
                span = own
            case .joined(let partner):
                span = partner.map { hull($0, moved) } ?? moved
            }
            addLine(&lines, axis: axis, position: match.position, span: span)
        }
        return lines
    }

    /// The lower kind wins; within a kind the smaller distance wins.
    private static func ranksBefore(_ a: Candidate, _ b: Candidate) -> Bool {
        (a.kind.rawValue, abs(a.delta)) < (b.kind.rawValue, abs(b.delta))
    }

    /// Keeps the target when it lies within reach of the anchor.
    private static func consider(_ found: inout [Candidate], _ kind: SnapKind, _ anchor: Double,
                                 _ target: Double, _ span: LineSpan, _ reach: Double) {
        let delta = target - anchor
        guard delta.isFinite, within(delta, reach) else { return }
        found.append(Candidate(kind: kind, delta: delta, position: target, span: span))
    }

    /// Adds a line, or widens the span of a line that is already there.
    private static func addLine(_ lines: inout [SnapGuide], axis: SnapGuide.Axis, position: Double, span: ClosedRange<Double>?) {
        if let index = lines.firstIndex(where: { $0.axis == axis && abs($0.position - position) <= epsilon }) {
            lines[index].span = merged(lines[index].span, span)
        } else {
            lines.append(SnapGuide(axis: axis, position: position, span: span))
        }
    }

    /// True when a distance lies within reach, in either direction. Plain comparisons: `abs` is slow in debug builds.
    @inline(__always)
    private static func within(_ delta: Double, _ reach: Double) -> Bool {
        delta <= reach && -delta <= reach
    }

    /// True when two rectangles share some part of the range on the other axis.
    private static func sharesAcross(_ other: Rect, _ rect: Rect, _ along: Along) -> Bool {
        along == .x ? (other.y < rect.maxY && other.maxY > rect.y) : (other.x < rect.maxX && other.maxX > rect.x)
    }

    /// The smallest range that holds both.
    private static func hull(_ a: ClosedRange<Double>, _ b: ClosedRange<Double>) -> ClosedRange<Double> {
        min(a.lowerBound, b.lowerBound)...max(a.upperBound, b.upperBound)
    }

    /// The hull of two spans. A nil span (the whole canvas) stays nil.
    private static func merged(_ a: ClosedRange<Double>?, _ b: ClosedRange<Double>?) -> ClosedRange<Double>? {
        guard let a, let b else { return nil }
        return hull(a, b)
    }

    private static func reach(tolerance: Double, zoom: Double) -> Double? {
        guard tolerance.isFinite, tolerance >= 0, zoom.isFinite, zoom > 0 else { return nil }
        return tolerance / zoom
    }

    // MARK: Moving the rectangle

    private enum Side {
        case lower, middle, upper
    }

    private struct Anchor {
        var side: Side
        var value: Double
    }

    /// The positions of the rectangle that may snap: its three positions when it moves, the moving edge when it resizes.
    private static func anchors(_ along: Along, of rect: Rect, motion: SnapMotion) -> [Anchor] {
        let lower = rect.lower(along), upper = rect.upper(along)
        switch motion {
        case .move:
            return [Anchor(side: .lower, value: lower), Anchor(side: .middle, value: (lower + upper) / 2),
                    Anchor(side: .upper, value: upper)]
        case .resize(let x, let y):
            switch along == .x ? x : y {
            case .lower?: return [Anchor(side: .lower, value: lower)]
            case .upper?: return [Anchor(side: .upper, value: upper)]
            case nil: return []
            }
        }
    }

    /// Moves the rectangle by a delta on one axis. A resize keeps the opposite edge where it is.
    private static func apply(_ delta: Double, along: Along, motion: SnapMotion, to rect: inout Rect) {
        guard delta != 0 else { return }
        switch motion {
        case .move:
            if along == .x { rect.x += delta } else { rect.y += delta }
        case .resize(let x, let y):
            switch along == .x ? x : y {
            case .lower?:
                if along == .x {
                    rect.x += delta
                    rect.w = max(0, rect.w - delta)
                } else {
                    rect.y += delta
                    rect.h = max(0, rect.h - delta)
                }
            case .upper?:
                if along == .x { rect.w = max(0, rect.w + delta) } else { rect.h = max(0, rect.h + delta) }
            case nil:
                break
            }
        }
    }
}

/// An axis of the board.
enum Along: Sendable {
    case x, y
}

private extension Rect {
    func lower(_ along: Along) -> Double { along == .x ? x : y }
    func upper(_ along: Along) -> Double { along == .x ? maxX : maxY }
    /// The range on the other axis.
    func across(_ along: Along) -> ClosedRange<Double> { along == .x ? y...maxY : x...maxX }
}
