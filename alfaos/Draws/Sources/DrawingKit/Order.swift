import Foundation

enum Order {
    enum Viewer {
        case direction(Double, Double, Double)
        case eye(Double, Double, Double)

        func component(_ axis: Int) -> Double {
            switch self {
            case .direction(let x, let y, let z), .eye(let x, let y, let z):
                return axis == 0 ? x : (axis == 1 ? y : z)
            }
        }
    }

    static let epsilon = 1e-6

    static func compare(_ a: Part, _ b: Part, _ viewer: Viewer) -> Int {
        var bNearer = false, aNearer = false, apart = false
        for axis in 0..<3 {
            let v = viewer.component(axis)
            if a.high(axis) <= b.low(axis) + epsilon {
                apart = true
                let side = side(plane: (a.high(axis) + b.low(axis)) / 2, axis: v, viewer: viewer)
                if side > 0 { bNearer = true } else if side < 0 { aNearer = true }
            }
            if b.high(axis) <= a.low(axis) + epsilon {
                apart = true
                let side = side(plane: (b.high(axis) + a.low(axis)) / 2, axis: v, viewer: viewer)
                if side > 0 { aNearer = true } else if side < 0 { bNearer = true }
            }
        }
        if !apart {
            let da = depth(a, viewer), db = depth(b, viewer)
            return da != db ? (da > db ? 1 : -1) : (a.id < b.id ? 1 : -1)
        }
        if bNearer == aNearer { return 0 }
        return bNearer ? 1 : -1
    }

    private static func side(plane: Double, axis value: Double, viewer: Viewer) -> Double {
        switch viewer {
        case .direction: return -value
        case .eye: return value - plane
        }
    }

    static func depth(_ p: Part, _ viewer: Viewer) -> Double {
        switch viewer {
        case .direction(let x, let y, let z):
            return p.center(0) * x + p.center(1) * y + p.center(2) * z
        case .eye(let x, let y, let z):
            let dx = p.center(0) - x, dy = p.center(1) - y, dz = p.center(2) - z
            return (dx * dx + dy * dy + dz * dz).squareRoot()
        }
    }

    static func farToNear(_ parts: [Part], _ viewer: Viewer) -> [Part] {
        let ps = parts.sorted { $0.id < $1.id }
        let n = ps.count
        var next = Array(repeating: [Int](), count: n)
        for i in 0..<n {
            for j in (i + 1)..<max(n, i + 1) {
                switch compare(ps[i], ps[j], viewer) {
                case 1: next[i].append(j)
                case -1: next[j].append(i)
                default: break
                }
            }
        }
        let components = tarjan(next)
        var owner = Array(repeating: 0, count: n)
        for (c, members) in components.enumerated() { for m in members { owner[m] = c } }
        let count = components.count
        var after = Array(repeating: Set<Int>(), count: count)
        var indegree = Array(repeating: 0, count: count)
        for i in 0..<n {
            for j in next[i] where owner[i] != owner[j] {
                if after[owner[i]].insert(owner[j]).inserted { indegree[owner[j]] += 1 }
            }
        }
        let key = components.map { $0.min() ?? 0 }
        var ready = (0..<count).filter { indegree[$0] == 0 }
        var out: [Int] = []
        while !ready.isEmpty {
            ready.sort { key[$0] < key[$1] }
            let c = ready.removeFirst()
            let members = components[c].sorted {
                let da = depth(ps[$0], viewer), db = depth(ps[$1], viewer)
                return da != db ? da > db : $0 < $1
            }
            out += members
            for d in after[c] {
                indegree[d] -= 1
                if indegree[d] == 0 { ready.append(d) }
            }
        }
        return out.map { ps[$0] }
    }

    static func tarjan(_ next: [[Int]]) -> [[Int]] {
        let n = next.count
        var index = 0
        var indices = Array(repeating: -1, count: n)
        var low = Array(repeating: 0, count: n)
        var onStack = Array(repeating: false, count: n)
        var stack: [Int] = []
        var result: [[Int]] = []

        func visit(_ v: Int) {
            indices[v] = index; low[v] = index; index += 1
            stack.append(v); onStack[v] = true
            for w in next[v] {
                if indices[w] < 0 {
                    visit(w)
                    low[v] = min(low[v], low[w])
                } else if onStack[w] {
                    low[v] = min(low[v], indices[w])
                }
            }
            if low[v] == indices[v] {
                var component: [Int] = []
                while let w = stack.popLast() {
                    onStack[w] = false
                    component.append(w)
                    if w == v { break }
                }
                result.append(component)
            }
        }

        for v in 0..<n where indices[v] < 0 { visit(v) }
        return result
    }
}
