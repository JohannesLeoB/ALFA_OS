import Design
import Foundation

enum LaneLayoutEngine {
    static func available(_ windowWidth: Double, _ g: Measure) -> Double {
        windowWidth - 2 * g.margin - 2 * g.gap
    }

    static func fits(_ folded: [Bool], preferred: [Double], limit: [Double], avail: Double, fold: Double) -> Bool {
        let open = (0..<3).filter { !folded[$0] }
        let flex = open.contains(1) ? 1 : (open.contains(2) ? 2 : 0)
        let need = open.reduce(0.0) { $0 + ($1 != flex && preferred[$1] > 0 ? preferred[$1] : limit[$1]) }
        return need <= avail - fold * Double(3 - open.count)
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
        for i in rules.yield.reversed() where folded[i] && mode.squeezed[i] && !(i == LaneKind.trailing.index && foldTrailing) {
            var trial = folded
            trial[i] = false
            if fits(trial, preferred: preferred, limit: limit, avail: avail, fold: fold) { folded = trial }
        }
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
            next.squeezed[o] = false
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
        let before = start.map { $0 <= fold }
        for k in 0..<3 {
            var shown = before
            shown[k] = false
            let yielded = before[k] && !mode.folded[k]
                && !fits(shown, preferred: mode.preferred, limit: limit, avail: start.reduce(0, +), fold: fold)
            next.preferred[k] = f[k] ? (start[k] > fold ? start[k] : (yielded ? mode.preferred[k] : limit[k])) : w[k].rounded()
            next.folded[k] = f[k]
            next.squeezed[k] = f[k] && (start[k] > fold || yielded || mode.squeezed[k])
        }
        if !f[1] { next.preferred[1] = 0 }
        return next
    }

    static func toggleFold(lane: LaneKind, mode: LaneMode) -> LaneMode {
        var next = mode
        next.maximized = nil
        next.folded[lane.index].toggle()
        next.squeezed[lane.index] = false
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
