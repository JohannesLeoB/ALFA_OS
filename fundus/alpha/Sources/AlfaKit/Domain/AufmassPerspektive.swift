import Foundation

public struct PerspektivPunkt: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

public struct Fluchtgruppe: Equatable, Sendable {
    public var linienIndizes: [Int]
    public var fluchtpunkt: PerspektivPunkt?
    public var richtungX: Double
    public var richtungY: Double
    public init(linienIndizes: [Int], fluchtpunkt: PerspektivPunkt?, richtungX: Double, richtungY: Double) {
        self.linienIndizes = linienIndizes
        self.fluchtpunkt = fluchtpunkt
        self.richtungX = richtungX
        self.richtungY = richtungY
    }
}

public enum AufmassPerspektive {
    public static func fluchtpunkt(aus lines: [BildLinie]) -> PerspektivPunkt? {
        var a11 = 0.0, a12 = 0.0, a22 = 0.0, b1 = 0.0, b2 = 0.0
        var gueltige = 0
        for line in lines {
            let dx = line.ende.x - line.start.x
            let dy = line.ende.y - line.start.y
            let laenge = (dx * dx + dy * dy).squareRoot()
            guard laenge > 1e-9 else { continue }
            let nx = -dy / laenge
            let ny =  dx / laenge
            let c = nx * line.start.x + ny * line.start.y
            a11 += nx * nx; a12 += nx * ny; a22 += ny * ny
            b1 += c * nx;   b2 += c * ny
            gueltige += 1
        }
        guard gueltige >= 2 else { return nil }
        let det = a11 * a22 - a12 * a12
        guard abs(det) > 1e-9 else { return nil }
        let x = ( a22 * b1 - a12 * b2) / det
        let y = (-a12 * b1 + a11 * b2) / det
        return PerspektivPunkt(x: x, y: y)
    }

    public static func horizont(fluchtpunkte vps: [PerspektivPunkt]) -> (PerspektivPunkt, PerspektivPunkt)? {
        guard vps.count >= 2 else { return nil }
        let a = vps[0], b = vps[1]
        let dx = b.x - a.x
        guard abs(dx) > 1e-9 else {
            return (PerspektivPunkt(x: a.x, y: 0), PerspektivPunkt(x: a.x, y: 1))
        }
        let m = (b.y - a.y) / dx
        return (PerspektivPunkt(x: 0, y: a.y + m * (0 - a.x)),
                PerspektivPunkt(x: 1, y: a.y + m * (1 - a.x)))
    }

    public static func leitstrahl(vonFluchtpunkt vp: PerspektivPunkt,
                                  durch p: PerspektivPunkt) -> (PerspektivPunkt, PerspektivPunkt)? {
        let dx = p.x - vp.x, dy = p.y - vp.y
        guard dx * dx + dy * dy > 1e-12 else { return nil }
        var tMin = -Double.greatestFiniteMagnitude, tMax = Double.greatestFiniteMagnitude
        func klemme(_ richtung: Double, _ start: Double) -> Bool {
            if abs(richtung) < 1e-12 { return start >= 0 && start <= 1 }
            let t0 = (0 - start) / richtung, t1 = (1 - start) / richtung
            tMin = max(tMin, min(t0, t1)); tMax = min(tMax, max(t0, t1))
            return tMin <= tMax
        }
        guard klemme(dx, vp.x), klemme(dy, vp.y), tMin <= tMax else { return nil }
        return (PerspektivPunkt(x: vp.x + tMin * dx, y: vp.y + tMin * dy),
                PerspektivPunkt(x: vp.x + tMax * dx, y: vp.y + tMax * dy))
    }

    public static func snapEndeAufFluchtpunkt(start: PerspektivPunkt, roherEnd: PerspektivPunkt,
                                              fluchtpunkt vp: PerspektivPunkt,
                                              maxWinkelGrad: Double = 7) -> PerspektivPunkt? {
        let ex = roherEnd.x - start.x, ey = roherEnd.y - start.y
        let vx = vp.x - start.x, vy = vp.y - start.y
        let eLaenge = (ex * ex + ey * ey).squareRoot()
        let vLaenge = (vx * vx + vy * vy).squareRoot()
        guard eLaenge > 1e-9, vLaenge > 1e-9 else { return nil }
        var cosWinkel = (ex * vx + ey * vy) / (eLaenge * vLaenge)
        cosWinkel = max(-1, min(1, cosWinkel))
        let angle = acos(cosWinkel) * 180 / .pi
        let winkelZurAchse = min(angle, 180 - angle)
        guard winkelZurAchse <= maxWinkelGrad else { return nil }
        let zumVP = (ex * vx + ey * vy) >= 0
        let ux = (zumVP ? vx : -vx) / vLaenge
        let uy = (zumVP ? vy : -vy) / vLaenge
        return PerspektivPunkt(x: start.x + ux * eLaenge, y: start.y + uy * eLaenge)
    }

    public static func snapEndeAufNaechstenFluchtpunkt(start: PerspektivPunkt, roherEnd: PerspektivPunkt,
                                                       fluchtpunkte vps: [PerspektivPunkt],
                                                       maxWinkelGrad: Double = 7) -> PerspektivPunkt? {
        var bestes: PerspektivPunkt?
        var besterWinkel = maxWinkelGrad
        for vp in vps {
            let ex = roherEnd.x - start.x, ey = roherEnd.y - start.y
            let vx = vp.x - start.x, vy = vp.y - start.y
            let eLaenge = (ex * ex + ey * ey).squareRoot()
            let vLaenge = (vx * vx + vy * vy).squareRoot()
            guard eLaenge > 1e-9, vLaenge > 1e-9 else { continue }
            var cosWinkel = (ex * vx + ey * vy) / (eLaenge * vLaenge)
            cosWinkel = max(-1, min(1, cosWinkel))
            let winkelZurAchse = min(acos(cosWinkel) * 180 / .pi, 180 - acos(cosWinkel) * 180 / .pi)
            if winkelZurAchse <= besterWinkel,
               let snap = snapEndeAufFluchtpunkt(start: start, roherEnd: roherEnd,
                                                 fluchtpunkt: vp, maxWinkelGrad: maxWinkelGrad) {
                besterWinkel = winkelZurAchse
                bestes = snap
            }
        }
        return bestes
    }

    public static func clustereFluchtpunkte(aus lines: [BildLinie],
                                            maxAnzahl: Int = 3,
                                            toleranz: Double = 0.02) -> [Fluchtgruppe] {
        struct Vorb { let idx: Int; let px: Double; let py: Double; let nx: Double; let ny: Double; let dx: Double; let dy: Double }
        var vorb: [Vorb] = []
        for (i, l) in lines.enumerated() {
            let dx = l.ende.x - l.start.x, dy = l.ende.y - l.start.y
            let len = (dx * dx + dy * dy).squareRoot()
            guard len > 1e-9 else { continue }
            vorb.append(Vorb(idx: i, px: l.start.x, py: l.start.y, nx: -dy / len, ny: dx / len, dx: dx / len, dy: dy / len))
        }
        guard vorb.count >= 2 else { return [] }
        let map = Dictionary(uniqueKeysWithValues: vorb.map { ($0.idx, $0) })

        func spacing(_ v: PerspektivPunkt, _ w: Vorb) -> Double { abs(w.nx * (v.x - w.px) + w.ny * (v.y - w.py)) }
        func schnitt(_ a: Vorb, _ b: Vorb) -> PerspektivPunkt? {
            let det = a.nx * b.ny - a.ny * b.nx
            guard abs(det) > 1e-9 else { return nil }
            let c1 = a.nx * a.px + a.ny * a.py, c2 = b.nx * b.px + b.ny * b.py
            return PerspektivPunkt(x: (c1 * b.ny - c2 * a.ny) / det, y: (a.nx * c2 - b.nx * c1) / det)
        }
        func angle(_ w: Vorb) -> Double { var a = atan2(w.dy, w.dx); if a < 0 { a += .pi }; return a }
        func parallelNah(_ a: Vorb, _ b: Vorb, _ tolRad: Double) -> Bool {
            let d = angle(a) - angle(b)
            let m = d - (d / Double.pi).rounded() * Double.pi
            return abs(m) <= tolRad
        }
        func mittlereRichtung(_ idxs: [Int]) -> (Double, Double) {
            var sx = 0.0, sy = 0.0
            for i in idxs { if let w = map[i] { let a = 2 * angle(w); sx += cos(a); sy += sin(a) } }
            let a = atan2(sy, sx) / 2
            return (cos(a), sin(a))
        }

        var verbleibend = Set(vorb.map { $0.idx })
        var groups: [Fluchtgruppe] = []
        let winkelTol = 4.0 * Double.pi / 180

        while groups.count < maxAnzahl {
            let rest = vorb.filter { verbleibend.contains($0.idx) }
            guard rest.count >= 2 else { break }

            var besteInlier: [Int] = []
            var besterVP: PerspektivPunkt?
            var besteParallel = false

            for a in 0..<rest.count {
                for b in (a + 1)..<rest.count {
                    guard let vp = schnitt(rest[a], rest[b]) else { continue }
                    let inlier = rest.filter { spacing(vp, $0) <= toleranz }.map { $0.idx }
                    if inlier.count > besteInlier.count { besteInlier = inlier; besterVP = vp; besteParallel = false }
                }
            }

            for seed in rest {
                let inlier = rest.filter { parallelNah($0, seed, winkelTol) }.map { $0.idx }
                if inlier.count > besteInlier.count { besteInlier = inlier; besterVP = nil; besteParallel = true }
            }

            guard besteInlier.count >= 2 else { break }
            let vpRefined: PerspektivPunkt? = besteParallel ? nil : (fluchtpunkt(aus: besteInlier.map { lines[$0] }) ?? besterVP)
            let (rx, ry) = mittlereRichtung(besteInlier)
            groups.append(Fluchtgruppe(linienIndizes: besteInlier.sorted(), fluchtpunkt: vpRefined, richtungX: rx, richtungY: ry))
            for i in besteInlier { verbleibend.remove(i) }
        }

        if verbleibend.isEmpty == false, groups.isEmpty == false {
            for i in verbleibend.sorted() {
                guard let w = map[i] else { continue }
                var bestG = -1
                var bestD = toleranz * 3
                for (gi, g) in groups.enumerated() {
                    guard let vp = g.fluchtpunkt else { continue }
                    let d = spacing(vp, w)
                    if d < bestD { bestD = d; bestG = gi }
                }
                if bestG >= 0 { groups[bestG].linienIndizes.append(i); groups[bestG].linienIndizes.sort() }
            }
        }
        return groups
    }
}
