import Design

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

        let w = solve([mode.folded[0], mode.folded[1], mode.folded[2] || foldTrailing])
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
        if let top = rules.maximum[o] { v = min(max(v, limit[o]), top) }
        let opposite = 2 - o
        if start[opposite] > fold && abs(v - start[opposite]) < Tokens.Size.laneSnap { v = start[opposite] }
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
        next.pinned = true
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
