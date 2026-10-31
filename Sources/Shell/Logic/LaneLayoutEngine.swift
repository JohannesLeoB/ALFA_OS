import Design
import Foundation

enum LaneLayoutEngine {
    static func available(_ windowWidth: Double, _ g: Measure) -> Double {
        windowWidth - 2 * g.margin - 2 * g.gap
    }

    static func widths(windowWidth: Double, mode: LaneMode, measure g: Measure, rules: AreaRules, foldTrailing: Bool = false) -> LaneWidths {
        let avail = available(windowWidth, g)
        let fold = g.laneFolded
        if let maximized = mode.maximized {
            var w = [fold, fold, fold]
            w[maximized.index] = avail - 2 * fold
            return LaneWidths(leading: w[0], center: w[1], trailing: w[2])
        }
        let limit = rules.minimum
        let preferred = mode.preferred

        func solve(_ folded: [Bool]) -> [Double] {
            let open = (0..<3).filter { !folded[$0] }
            var w = [fold, fold, fold]
            if open.isEmpty { return w }
            let room = avail - fold * Double(3 - open.count)
            let flex = open.contains(1) ? 1 : (open.contains(2) ? 2 : 0)
            var want: [Int: Double] = [:]
            var used = 0.0
            for i in open where i != flex && preferred[i] > 0 {
                want[i] = preferred[i]
                used += preferred[i]
            }
            for i in open where want[i] == nil {
                want[i] = max(room - used, limit[i])
            }
            var free = open
            var rest = room
            var round = 0
            while round < 4 && !free.isEmpty {
                round += 1
                let factor = rest / free.reduce(0) { $0 + want[$1]! }
                var hit = false
                for i in free {
                    let floor = min(want[i]!, limit[i])
                    if want[i]! * factor < floor {
                        w[i] = floor
                        rest -= floor
                        free.removeAll { $0 == i }
                        hit = true
                    }
                }
                if !hit {
                    for i in free { w[i] = want[i]! * factor }
                    free = []
                }
            }
            func yielded() -> [Bool] {
                var next = folded
                if let first = rules.yield.first(where: { !folded[$0] }) { next[first] = true }
                return next
            }
            if rest < -0.5 && open.count > 1 { return solve(yielded()) }
            var r = w.map { $0.rounded() }
            let fix = open.contains(flex) ? flex : open[0]
            for i in open where i != fix { r[i] = max(limit[i], r[i]) }
            r[fix] = avail - (0..<3).filter { $0 != fix }.reduce(0) { $0 + r[$1] }
            if r[fix] < limit[fix] - 0.5 && open.count > 1 { return solve(yielded()) }
            return r
        }

        var folded = [mode.folded[0], mode.folded[1], mode.folded[2] || foldTrailing]
        if !folded.contains(false) { folded[LaneKind.center.index] = false }
        let w = solve(folded)
        return LaneWidths(leading: w[0], center: w[1], trailing: w[2])
    }

    static func drag(lane: LaneKind, proposed: Double, start: [Double], mode: LaneMode, measure g: Measure, rules: AreaRules) -> LaneMode {
        guard lane != .center else { return mode }
        let fold = g.laneFolded
        let limit = rules.minimum
        let o = lane.index
        var next = mode
        next.maximized = nil
        if proposed < g.foldAt {
            next.folded[o] = true
            return next
        }
        var v = proposed
        let opposite = 2 - o
        if start[opposite] > fold && abs(v - start[opposite]) < Tokens.Size.laneSnap { v = start[opposite] }
        if let top = rules.maximum[o] { v = min(v, top) }
        let order = rules.yield.filter { $0 != o }
        var w = start
        var f = start.map { $0 <= fold }
        w[o] = v.rounded()
        f[o] = false
        var need = w[o] - start[o]
        let hysteresis = Tokens.Size.laneHysteresis
        if need > 0 {
            for i in order {
                if need <= 0 { break }
                if f[i] { continue }
                let room = w[i] - limit[i]
                let take = min(room, need)
                w[i] -= take
                need -= take
                if need > hysteresis {
                    need -= w[i] - fold
                    w[i] = fold
                    f[i] = true
                } else if need > 0 {
                    w[o] -= need
                    need = 0
                }
            }
            if need > 0 { w[o] -= need }
        } else {
            var give = -need
            for j in order.reversed() {
                if !f[j] || j == o { continue }
                if give >= limit[j] - fold + hysteresis {
                    give -= limit[j] - fold
                    w[j] = limit[j]
                    f[j] = false
                }
            }
        }
        for k in 0..<3 {
            next.preferred[k] = f[k] ? (start[k] > fold ? start[k] : limit[k]) : w[k].rounded()
            next.folded[k] = f[k]
        }
        if !f[1] { next.preferred[1] = 0 }
        return next
    }

    static func toggleFold(lane: LaneKind, mode: LaneMode) -> LaneMode {
        var next = mode
        next.maximized = nil
        next.folded[lane.index].toggle()
        return next
    }

    static func toggleMaximize(lane: LaneKind, mode: LaneMode) -> LaneMode {
        var next = mode
        next.maximized = mode.maximized == lane ? nil : lane
        return next
    }
}

public enum MenuAlignEngine {
    public static func left(anchor: Double, anchorWidth: Double, width: Double, lanes: LaneWidths, measure: Measure, windowWidth: Double) -> Double {
        let all = lanes.all
        let lefts = measure.lefts(lanes)
        let index = measure.lane(at: anchor, lanes).index
        let start = lefts[index]
        let end = start + all[index]
        var x = anchor + anchorWidth / 2 < (start + end) / 2 ? anchor : anchor + anchorWidth - width
        if x < start && start + width <= end { x = start }
        if x + width > end && end - width >= start { x = end - width }
        return max(measure.margin, min(x, windowWidth - width - measure.margin))
    }
}

public enum MenuWidthEngine {
    public static func width(fitting natural: Double) -> Double {
        let step = Tokens.Size.menuWidthStep
        let rounded = (natural / step).rounded(.up) * step
        return min(max(rounded, Tokens.Size.menuMinWidth), Tokens.Size.menuMaxWidth)
    }
}

public enum TileGrid {
    public static func columns(width: Double, minimum: Double, gap: Double) -> Int {
        guard width.isFinite, minimum > 0 else { return 1 }
        return max(1, Int(((width + gap) / (minimum + gap)).rounded(.down)))
    }

    public static func columnWidth(width: Double, count: Int, gap: Double) -> Double {
        (width - Double(count - 1) * gap) / Double(count)
    }

    public static func rowTops(top: Double, count: Int, columns: Int, height: Double, gap: Double) -> [Double] {
        let rows = columns > 0 ? (max(0, count) + columns - 1) / columns : 0
        return (0..<rows).map { top + Double($0) * (height + gap) }
    }

    public static func snap(_ proposed: Double, rows: [Double], inset: Double, limit: Double) -> Double {
        let ceiling = max(0, limit)
        return rows.map { min(ceiling, max(0, $0 - inset)) }.reduce(0) { abs($1 - proposed) < abs($0 - proposed) ? $1 : $0 }
    }

    public static func active(tops: [Double], offset: Double, reach: Double, viewport: Double, content: Double) -> Int {
        guard !tops.isEmpty else { return 0 }
        if offset > 0, offset + viewport >= content - 2 { return tops.count - 1 }
        return tops.lastIndex { $0 - offset <= reach } ?? 0
    }
}

public struct BlobPoint: Sendable, Equatable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct BlobSize: Sendable, Equatable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public enum BlobEdge: String, Sendable, Codable {
    case top
    case leading
    case trailing
}

public struct BlobPlacement: Sendable, Codable, Equatable {
    public var edge: BlobEdge
    var offset: Double

    init(edge: BlobEdge, offset: Double) {
        self.edge = edge
        self.offset = offset
    }

    static func home(measure m: Measure) -> BlobPlacement {
        BlobPlacement(edge: .top, offset: m.margin)
    }

    var isDocked: Bool { edge == .leading || edge == .trailing }

    var normalized: BlobPlacement {
        isDocked ? self : BlobPlacement(edge: .top, offset: offset)
    }

    func origin(window: BlobSize, measure m: Measure) -> BlobPoint {
        func clamp(_ value: Double) -> Double { min(window.height - m.blobHeight - m.margin, max(m.strip, value)) }
        switch edge {
        case .top:
            return BlobPoint(x: m.margin, y: m.blobTop)
        case .leading:
            return BlobPoint(x: 0, y: clamp(offset))
        case .trailing:
            return BlobPoint(x: window.width - m.blobDock, y: clamp(offset))
        }
    }

    static func settle(dropAt center: BlobPoint, velocity: BlobPoint, window: BlobSize, measure m: Measure) -> BlobPlacement {
        let rate = Tokens.Motion.deceleration
        let projection = rate / (1 - rate) / 1000
        let x = center.x - m.blobWidth / 2 + velocity.x * projection
        let y = center.y - m.blobHeight / 2 + velocity.y * projection
        let near = hypot(x - m.margin, y - m.blobTop) < Tokens.Size.blobHomeRadius
        if y < m.strip || near { return home(measure: m) }
        let edge: BlobEdge = x + m.blobWidth / 2 < window.width / 2 ? .leading : .trailing
        return BlobPlacement(edge: edge, offset: min(window.height - m.blobHeight - m.margin, max(m.strip, y)))
    }

    func opensUpward(window: BlobSize, measure m: Measure) -> Bool {
        origin(window: window, measure: m).y + m.blobHeight / 2 > window.height / 2
    }

    public func menuRoom(window: BlobSize, measure m: Measure) -> Double {
        let y = origin(window: window, measure: m).y
        let room = opensUpward(window: window, measure: m) ? y - m.margin : window.height - m.margin - y - m.blobHeight
        return max(Tokens.Size.blobMenuMinHeight, room - Tokens.Size.menuEdge)
    }

    static func awakeWidth(label: Double) -> Double {
        let need = (Tokens.Spacing.blobInset + Tokens.Size.symbolSize + Tokens.Size.menuRowGap + label + Tokens.Size.blobLabelPadding).rounded(.up)
        return need <= Tokens.Size.blobAwakeWidth ? Tokens.Size.blobAwakeWidth : Tokens.Size.blobPopupFallbackWidth
    }
}

public enum CardStackEngine {
    public static func tops(count: Int) -> [Double] {
        var result: [Double] = []
        var next = Tokens.Spacing.step8
        for index in 0..<count {
            result.append(next)
            next += (count - 1 - index) > Tokens.Count.stackHeads ? Tokens.Spacing.step8 : Tokens.Size.headerHeight
        }
        return result
    }

    public static func levelIndex(depth: Int) -> Int {
        min(depth, Tokens.stackLight.count) - 1
    }

    public static func metaOpacity(depth: Int) -> Double {
        levelIndex(depth: depth) >= Tokens.stackLight.count - 2 ? Tokens.Opacity.cardMetaDeep : Tokens.Opacity.cardMeta
    }
}

public enum OverviewSize: Equatable, Sendable, CaseIterable {
    case small
    case medium
    case large

    public var tileHeight: Double {
        switch self {
        case .small: Tokens.Size.overviewTileHeightSmall
        case .medium: Tokens.Size.overviewTileHeightMedium
        case .large: Tokens.Size.overviewTileHeightLarge
        }
    }

    public var tileMinWidth: Double {
        switch self {
        case .small: Tokens.Size.overviewTileMinWidthSmall
        case .medium: Tokens.Size.overviewTileMinWidthMedium
        case .large: Tokens.Size.overviewTileMinWidthLarge
        }
    }

    public var lines: Int {
        switch self {
        case .small: Tokens.Count.overviewLinesSmall
        case .medium: Tokens.Count.overviewLinesMedium
        case .large: Tokens.Count.overviewLinesLarge
        }
    }
}
