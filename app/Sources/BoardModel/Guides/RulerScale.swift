import Foundation
import ALFAcolorCore
import Geometry

/// One tick of a ruler: where it lies on the board, its value in the unit of the ruler, and whether it is a major tick.
public struct RulerTick: Equatable, Sendable {
    /// The distance from the origin in points.
    public var points: Double
    /// The distance from the origin in the unit of the ruler.
    public var value: Double
    public var isMajor: Bool
}

/// The division of a ruler: the distance between labelled (major) and plain (minor) ticks, in the unit of the ruler.
/// The steps follow a 1-2-5 sequence, so the labels read 10, 20, 50 and so on, and the major ticks never
/// come closer than `spacing` screen points.
public struct RulerScale: Equatable, Sendable {
    /// Each major step with its minor step. Minor steps are a tenth, a quarter or a fifth of the major step.
    private static let ladder: [(major: Double, minor: Double)] = [
        (1, 0.1), (2, 0.5), (5, 1), (10, 1), (20, 5), (50, 10), (100, 10), (200, 50), (500, 100),
        (1000, 100), (2000, 500), (5000, 1000), (10000, 1000), (20000, 5000), (50000, 10000),
    ]

    /// The closest together that two major ticks may lie, in screen points.
    public static let spacing: Double = 48

    /// Most ticks that one ruler draws. Keeps a very far zoom from making millions of ticks.
    public static let tickLimit = 2_000

    public var unit: LengthUnit
    /// The pixel scale that a pixel unit uses (pixels per point). 1 for the other units.
    public var scale: Double
    public var major: Double
    public var minor: Double

    /// The division for a zoom level: the smallest major step whose ticks lie at least `spacing` screen points apart.
    /// A zoom or scale that is not finite and positive gives the coarsest division.
    public static func make(unit: LengthUnit, zoom: Double, scale: Double = 1) -> RulerScale {
        let coarsest = ladder[ladder.count - 1]
        guard zoom.isFinite, zoom > 0, scale.isFinite, scale > 0 else {
            return RulerScale(unit: unit, scale: 1, major: coarsest.major, minor: coarsest.minor)
        }
        // Screen points for one unit at this zoom.
        let perUnit = unit.pointsPerUnit(scale: scale) * zoom
        let step = ladder.first { $0.major * perUnit >= spacing } ?? coarsest
        return RulerScale(unit: unit, scale: scale, major: step.major, minor: step.minor)
    }

    /// The ticks between two distances from the origin, in points. The ticks are sorted from `start` to `end`;
    /// a reversed range gives no ticks. More than `tickLimit` ticks give none.
    public func ticks(from start: Double, to end: Double) -> [RulerTick] {
        guard start.isFinite, end.isFinite else { return [] }
        let low = unit.value(points: min(start, end), scale: scale)
        let high = unit.value(points: max(start, end), scale: scale)
        guard low.isFinite, high.isFinite, minor > 0 else { return [] }
        let firstIndex = (low / minor).rounded(.down)
        let lastIndex = (high / minor).rounded(.up)
        // An index beyond the integer limit is not counted: the ruler draws nothing there, and nothing traps.
        guard abs(firstIndex) <= NumberLimit.integer, abs(lastIndex) <= NumberLimit.integer,
              lastIndex - firstIndex <= Double(Self.tickLimit) else { return [] }
        let first = firstIndex.clampedInt, last = lastIndex.clampedInt
        guard first <= last else { return [] }
        return (first...last).map { index in
            let value = Double(index) * minor
            let ratio = value / major
            return RulerTick(points: unit.points(value, scale: scale), value: value,
                             isMajor: abs(ratio - ratio.rounded()) < 1e-9)
        }
    }
}

/// Which frame the rulers measure from. The origin is the top left corner of that frame.
public struct RulerFrame: Equatable, Sendable {
    public var id: ItemID
    /// The corner of the frame on the board, in points.
    public var x: Double
    public var y: Double
    /// The pixel scale of the frame: its own, else the first scale of its device, else 2.
    public var scale: Double
}

/// Chooses the frame of the rulers, in this order: the frame that holds the whole selection, the frame under
/// the pointer, and the frame that was used last. Among several frames the one on top wins.
public enum RulerOrigin {
    /// The frame to measure from, or nil when no frame qualifies. Frames that are not finite do not qualify.
    public static func pick(items: [Item], selection: Set<ItemID>, pointer: (x: Double, y: Double)?,
                            last: ItemID?) -> RulerFrame? {
        let frames = items.filter { item in
            if case .frame = item.content { return item.rect.isFinite }
            return false
        }
        let selected = items.filter { selection.contains($0.id) }
        if let box = bounds(of: selected) {
            if let found = topmost(frames.filter { contains($0.rect, box) }) { return frame(found) }
        }
        if let pointer, let found = topmost(frames.filter { $0.rect.contains(x: pointer.x, y: pointer.y) }) {
            return frame(found)
        }
        if let last, let found = frames.first(where: { $0.id == last }) {
            return frame(found)
        }
        return nil
    }

    private static func frame(_ item: Item) -> RulerFrame {
        var deviceID: String?, scale: Double?
        if case .frame(let device, _, let own, _, _) = item.content {
            deviceID = device
            scale = own
        }
        return RulerFrame(id: item.id, x: item.rect.x, y: item.rect.y,
                          scale: FrameScale.effective(deviceID: deviceID, scale: scale))
    }

    /// The topmost item: the highest z, and the later one in the list when z is equal.
    private static func topmost(_ items: [Item]) -> Item? {
        items.enumerated().max { ($0.element.z, $0.offset) < ($1.element.z, $1.offset) }?.element
    }

    private static func bounds(of items: [Item]) -> Rect? {
        guard let first = items.first else { return nil }
        var box = first.rect
        for item in items.dropFirst() {
            let x = min(box.x, item.rect.x), y = min(box.y, item.rect.y)
            box = Rect(x: x, y: y, w: max(box.maxX, item.rect.maxX) - x, h: max(box.maxY, item.rect.maxY) - y)
        }
        return box
    }

    /// True when the frame holds the box completely.
    private static func contains(_ frame: Rect, _ box: Rect) -> Bool {
        frame.x <= box.x && box.maxX <= frame.maxX && frame.y <= box.y && box.maxY <= frame.maxY
    }
}
