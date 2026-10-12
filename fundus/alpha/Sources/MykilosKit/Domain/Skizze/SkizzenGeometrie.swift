import Foundation

public enum SkizzenGeometrie {
    public static func enthaelt(_ points: [BildPunkt], _ p: BildPunkt) -> Bool {
        guard points.count >= 3 else { return false }
        var innen = false
        var j = points.count - 1
        for i in 0..<points.count {
            let pi = points[i], pj = points[j]
            if (pi.y > p.y) != (pj.y > p.y) {
                let schnittX = (pj.x - pi.x) * (p.y - pi.y) / (pj.y - pi.y) + pi.x
                if p.x < schnittX { innen.toggle() }
            }
            j = i
        }
        return innen
    }

    public static func enthaelt(form: SkizzenForm, point p: BildPunkt) -> Bool {
        switch form {
        case let .polylinie(pts, geschlossen): return geschlossen ? enthaelt(pts, p) : false
        case let .rechteck(r):                 return p.x >= r.minX && p.x <= r.maxX && p.y >= r.minY && p.y <= r.maxY
        case .freihand:                        return false
        }
    }

    public static func abstandZuStrecke(_ p: BildPunkt, _ a: BildPunkt, _ b: BildPunkt, aspekt: Double) -> Double {
        let px = p.x * aspekt, py = p.y
        let ax = a.x * aspekt, ay = a.y
        let bx = b.x * aspekt, by = b.y
        let dx = bx - ax, dy = by - ay
        let len2 = dx * dx + dy * dy
        guard len2 > 0 else {
            let ex = px - ax, ey = py - ay
            return (ex * ex + ey * ey).squareRoot()
        }
        var t = ((px - ax) * dx + (py - ay) * dy) / len2
        t = min(max(t, 0), 1)
        let cx = ax + t * dx, cy = ay + t * dy
        let ex = px - cx, ey = py - cy
        return (ex * ex + ey * ey).squareRoot()
    }

    public static func spacing(zu form: SkizzenForm, point p: BildPunkt, aspekt: Double) -> Double {
        if enthaelt(form: form, point: p) { return 0 }
        let pts = form.points
        guard pts.count >= 2 else {
            guard let a = pts.first else { return .greatestFiniteMagnitude }
            return abstandZuStrecke(p, a, a, aspekt: aspekt)
        }
        let n = pts.count
        let kanten = form.istGeschlossen ? n : n - 1
        var best = Double.greatestFiniteMagnitude
        for i in 0..<kanten {
            best = min(best, abstandZuStrecke(p, pts[i], pts[(i + 1) % n], aspekt: aspekt))
        }
        return best
    }

    public static func naechstesObjekt(_ objekte: [(id: UUID, form: SkizzenForm)],
                                       zu p: BildPunkt, aspekt: Double, radius: Double) -> UUID? {
        var best: (id: UUID, dist: Double)?
        for o in objekte {
            let d = spacing(zu: o.form, point: p, aspekt: aspekt)
            if d <= radius, d <= (best?.dist ?? .greatestFiniteMagnitude) { best = (o.id, d) }
        }
        return best?.id
    }

    public static func rastWinkel(von a: BildPunkt, zu b: BildPunkt, aspekt: Double,
                                  schwelleGrad: Double = 7) -> BildPunkt {
        let dx = (b.x - a.x) * aspekt
        let dy = (b.y - a.y)
        let len = (dx * dx + dy * dy).squareRoot()
        guard len > 0 else { return b }
        let angle = atan2(dy, dx)
        let schritt = Double.pi / 4
        let gerastet = (angle / schritt).rounded() * schritt
        let diff = abs(atan2(sin(angle - gerastet), cos(angle - gerastet)))
        guard diff <= schwelleGrad * .pi / 180 else { return b }
        let ndx = cos(gerastet) * len / aspekt
        let ndy = sin(gerastet) * len
        return BildPunkt(x: a.x + ndx, y: a.y + ndy)
    }

    public static func magnet(candidates: [BildPunkt], zu p: BildPunkt, aspekt: Double,
                              radius: Double) -> BildPunkt? {
        var best: (point: BildPunkt, dist: Double)?
        for k in candidates {
            let dx = (k.x - p.x) * aspekt, dy = (k.y - p.y)
            let d = (dx * dx + dy * dy).squareRoot()
            if d <= radius, d < (best?.dist ?? .greatestFiniteMagnitude) { best = (k, d) }
        }
        return best?.point
    }

    public static func angleDegrees(von a: BildPunkt, zu b: BildPunkt, aspekt: Double) -> Int {
        let dx = (b.x - a.x) * aspekt
        let dy = (b.y - a.y)
        guard dx != 0 || dy != 0 else { return 0 }
        var grad = atan2(-dy, dx) * 180 / .pi
        if grad < 0 { grad += 360 }
        return Int(grad.rounded())
    }
}
