import CoreGraphics
import Foundation

enum Projection {
    static let normals: [ViewKind] = [.front, .back, .top, .left, .right]

    static func viewDir(_ k: ViewKind) -> (Double, Double, Double) {
        switch k {
        case .front: return (0, 1, 0)
        case .back: return (0, -1, 0)
        case .top: return (0, 0, -1)
        case .right: return (-1, 0, 0)
        case .left: return (1, 0, 0)
        default: return (0, 1, 0)
        }
    }

    static func uv(_ x: Double, _ y: Double, _ z: Double, _ k: ViewKind) -> CGPoint {
        switch k {
        case .front: return CGPoint(x: x, y: z)
        case .back: return CGPoint(x: -x, y: z)
        case .top: return CGPoint(x: x, y: y)
        case .right: return CGPoint(x: y, y: z)
        case .left: return CGPoint(x: -y, y: z)
        default: return .zero
        }
    }

    static func rect(_ p: Part, _ k: ViewKind) -> CGRect {
        let a = uv(p.x, p.y, p.z, k), b = uv(p.maxX, p.maxY, p.maxZ, k)
        return CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    static func extent(_ ps: [Part], _ k: ViewKind) -> CGRect {
        ps.map { rect($0, k) }.reduce(CGRect.null) { $0.union($1) }
    }

    static func visibleRects(_ ps: [Part], _ k: ViewKind) throws -> [(id: String, rects: [CGRect])] {
        try Validate.parts(ps)
        guard normals.contains(k) else { throw DrawingError.unsupportedView(k.rawValue) }
        let d = viewDir(k)
        let near = Order.farToNear(ps, .direction(d.0, d.1, d.2)).reversed()
        var occluders: [CGRect] = []
        var out: [(id: String, rects: [CGRect])] = []
        for p in near {
            let r = rect(p, k)
            var pieces = [r]
            for o in occluders where o.intersects(r) {
                pieces = pieces.flatMap { subtract($0, o) }
                if pieces.isEmpty { break }
            }
            out.append((id: p.id, rects: pieces))
            occluders.append(r)
        }
        return out
    }

    static func subtract(_ a: CGRect, _ b: CGRect) -> [CGRect] {
        let e = CGFloat(Order.epsilon)
        let i = a.intersection(b)
        if i.isNull || i.width <= e || i.height <= e { return [a] }
        var r: [CGRect] = []
        if i.minY - a.minY > e { r.append(CGRect(x: a.minX, y: a.minY, width: a.width, height: i.minY - a.minY)) }
        if a.maxY - i.maxY > e { r.append(CGRect(x: a.minX, y: i.maxY, width: a.width, height: a.maxY - i.maxY)) }
        if i.minX - a.minX > e { r.append(CGRect(x: a.minX, y: i.minY, width: i.minX - a.minX, height: i.height)) }
        if a.maxX - i.maxX > e { r.append(CGRect(x: i.maxX, y: i.minY, width: a.maxX - i.maxX, height: i.height)) }
        return r
    }

    static let shadowNormal = 6

    static func faces(_ ps: [Part], spec: ViewSpec, shadow spread: Double? = nil) throws -> [Face2D] {
        try Validate.parts(ps)
        if let dist = spec.distance { guard dist.isFinite, dist > 0 else { throw DrawingError.invalidCamera } }
        guard spec.azimuth.isFinite, spec.elevation.isFinite else { throw DrawingError.invalidCamera }
        let a = spec.azimuth * .pi / 180, e = spec.elevation * .pi / 180
        let c = (center(ps, 0), center(ps, 1), center(ps, 2))
        let fwd = (sin(a) * cos(e), cos(a) * cos(e), -sin(e))
        let right = (cos(a), -sin(a), 0.0)
        let up = (sin(a) * sin(e), cos(a) * sin(e), cos(e))
        func cam(_ p: (Double, Double, Double)) -> (r: Double, u: Double, f: Double) {
            let dx = p.0 - c.0, dy = p.1 - c.1, dz = p.2 - c.2
            return (dx * right.0 + dy * right.1 + dz * right.2,
                    dx * up.0 + dy * up.1 + dz * up.2,
                    dx * fwd.0 + dy * fwd.1 + dz * fwd.2)
        }
        let near = 1.0
        let eye: (Double, Double, Double)? = spec.distance.map { (c.0 - fwd.0 * $0, c.1 - fwd.1 * $0, c.2 - fwd.2 * $0) }
        let viewer: Order.Viewer = eye.map { .eye($0.0, $0.1, $0.2) } ?? .direction(fwd.0, fwd.1, fwd.2)
        var out: [Face2D] = []
        func project(_ quad: [(Double, Double, Double)]) -> [CGPoint] {
            guard let dist = spec.distance else { return quad.map(cam).map { CGPoint(x: $0.r, y: $0.u) } }
            return clipNear(quad.map(cam), dist: dist, near: near).map { k in
                let s = dist / (k.f + dist)
                return CGPoint(x: k.r * s, y: k.u * s)
            }
        }
        if let spread, spread.isFinite, spread >= 0, let floor = ps.map(\.z).min() {
            for p in ps where p.z <= floor + Order.epsilon {
                let x0 = p.x - spread, x1 = p.maxX + spread, y0 = p.y - spread, y1 = p.maxY + spread
                let poly = project([(x0, y0, floor), (x1, y0, floor), (x1, y1, floor), (x0, y1, floor)])
                if poly.count >= 3 { out.append(Face2D(poly: poly, partID: p.id, normal: shadowNormal)) }
            }
        }
        for p in Order.farToNear(ps, viewer) {
            for (index, face) in quads(p).enumerated() {
                let (n, quad) = face
                let q0 = quad[0]
                let visible: Bool
                if let ey = eye {
                    visible = n.0 * (ey.0 - q0.0) + n.1 * (ey.1 - q0.1) + n.2 * (ey.2 - q0.2) > 1e-9
                } else {
                    visible = n.0 * fwd.0 + n.1 * fwd.1 + n.2 * fwd.2 < -1e-9
                }
                guard visible else { continue }
                let poly = project(quad)
                if poly.count >= 3 { out.append(Face2D(poly: poly, partID: p.id, normal: index)) }
            }
        }
        return out
    }

    static func clipNear(_ pts: [(r: Double, u: Double, f: Double)], dist: Double, near: Double) -> [(r: Double, u: Double, f: Double)] {
        func inside(_ p: (r: Double, u: Double, f: Double)) -> Bool { p.f + dist >= near }
        var out: [(r: Double, u: Double, f: Double)] = []
        for i in pts.indices {
            let cur = pts[i], prev = pts[(i + pts.count - 1) % pts.count]
            if inside(cur) != inside(prev) {
                let t = (near - dist - prev.f) / (cur.f - prev.f)
                out.append((prev.r + t * (cur.r - prev.r), prev.u + t * (cur.u - prev.u), near - dist))
            }
            if inside(cur) { out.append(cur) }
        }
        return out
    }

    static func center(_ ps: [Part], _ axis: Int) -> Double {
        let lo = ps.map { $0.low(axis) }.min() ?? 0, hi = ps.map { $0.high(axis) }.max() ?? 0
        return (lo + hi) / 2
    }

    static func quads(_ p: Part) -> [((Double, Double, Double), [(Double, Double, Double)])] {
        let x0 = p.x, x1 = p.maxX, y0 = p.y, y1 = p.maxY, z0 = p.z, z1 = p.maxZ
        return [
            ((0, -1, 0), [(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)]),
            ((0, 1, 0), [(x1, y1, z0), (x0, y1, z0), (x0, y1, z1), (x1, y1, z1)]),
            ((-1, 0, 0), [(x0, y1, z0), (x0, y0, z0), (x0, y0, z1), (x0, y1, z1)]),
            ((1, 0, 0), [(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)]),
            ((0, 0, -1), [(x0, y1, z0), (x1, y1, z0), (x1, y0, z0), (x0, y0, z0)]),
            ((0, 0, 1), [(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)])
        ]
    }
}
