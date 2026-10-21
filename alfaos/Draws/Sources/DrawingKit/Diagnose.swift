import Foundation

public enum Diagnose {
    public static let tolerance = 1e-3

    public static func cycles(_ parts: [Part], spec: ViewSpec) -> [[String]] {
        guard !parts.isEmpty, spec.azimuth.isFinite, spec.elevation.isFinite, abs(spec.elevation) < 90 else { return [] }
        let a = spec.azimuth * .pi / 180, e = spec.elevation * .pi / 180
        let fwd = (sin(a) * cos(e), cos(a) * cos(e), -sin(e))
        let viewer: Order.Viewer
        if let dist = spec.distance, dist.isFinite, dist > 0 {
            let c = (Projection.center(parts, 0), Projection.center(parts, 1), Projection.center(parts, 2))
            viewer = .eye(c.0 - fwd.0 * dist, c.1 - fwd.1 * dist, c.2 - fwd.2 * dist)
        } else {
            viewer = .direction(fwd.0, fwd.1, fwd.2)
        }
        let ps = parts.sorted { $0.id < $1.id }
        var next = Array(repeating: [Int](), count: ps.count)
        for i in ps.indices {
            for j in ps.indices where j > i {
                switch Order.compare(ps[i], ps[j], viewer) {
                case 1: next[i].append(j)
                case -1: next[j].append(i)
                default: break
                }
            }
        }
        return Order.tarjan(next).filter { $0.count > 1 }.map { $0.map { ps[$0].id }.sorted() }.sorted { $0.lexicographicallyPrecedes($1) }
    }

    public static func overlaps(_ parts: [Part]) -> [[String]] {
        let ps = parts.sorted { $0.id < $1.id }
        var out: [[String]] = []
        for i in ps.indices {
            for j in ps.indices where j > i {
                let inside = (0..<3).allSatisfy { axis in
                    min(ps[i].high(axis), ps[j].high(axis)) - max(ps[i].low(axis), ps[j].low(axis)) > tolerance
                }
                if inside { out.append([ps[i].id, ps[j].id]) }
            }
        }
        return out
    }
}
