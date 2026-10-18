import Foundation

public enum AufmassAutoBemassung {
    public enum Achse: String, Sendable, Equatable {
        case horizontal, vertikal

        public var label: String {
            switch self {
            case .horizontal: "Breite"
            case .vertikal:   "Höhe"
            }
        }
    }

    public struct Kandidat: Equatable, Sendable {
        public let line: BildLinie
        public let achse: Achse
        public init(line: BildLinie, achse: Achse) {
            self.line = line
            self.achse = achse
        }
    }

    public static func alleHauptkanten(ausPunkten points: [BildPunkt],
                                       mindestSpanne: Double = 0.12,
                                       achsToleranz: Double = 0.03,
                                       maxProAchse: Int = 8) -> [Kandidat] {
        [Achse.horizontal, .vertikal].flatMap {
            segmente(points, achse: $0, mindestSpanne: mindestSpanne,
                     achsToleranz: achsToleranz, maxProAchse: maxProAchse)
        }
    }

    static func segmente(_ points: [BildPunkt], achse: Achse,
                         mindestSpanne: Double, achsToleranz: Double, maxProAchse: Int) -> [Kandidat] {
        guard points.count >= 2, achsToleranz > 0 else { return [] }

        func quer(_ p: BildPunkt) -> Double { achse == .horizontal ? p.y : p.x }
        func laengs(_ p: BildPunkt) -> Double { achse == .horizontal ? p.x : p.y }

        var baender: [Int: (minL: Double, maxL: Double, summeQuer: Double, count: Int)] = [:]
        for p in points {
            let key = Int((quer(p) / achsToleranz).rounded(.down))
            let l = laengs(p)
            if var b = baender[key] {
                b.minL = min(b.minL, l); b.maxL = max(b.maxL, l)
                b.summeQuer += quer(p); b.count += 1
                baender[key] = b
            } else {
                baender[key] = (l, l, quer(p), 1)
            }
        }

        var roh: [(kandidat: Kandidat, laenge: Double, quer: Double)] = []
        for b in baender.values {
            let spanne = b.maxL - b.minL
            guard spanne >= mindestSpanne, b.count >= 2 else { continue }
            let q = b.summeQuer / Double(b.count)
            let line: BildLinie = achse == .horizontal
                ? BildLinie(start: BildPunkt(x: b.minL, y: q), ende: BildPunkt(x: b.maxL, y: q))
                : BildLinie(start: BildPunkt(x: q, y: b.minL), ende: BildPunkt(x: q, y: b.maxL))
            roh.append((Kandidat(line: line, achse: achse), spanne, q))
        }

        roh.sort { $0.laenge > $1.laenge }
        var akzeptiert: [(kandidat: Kandidat, quer: Double)] = []
        for r in roh {
            let doppelt = akzeptiert.contains { abs($0.quer - r.quer) <= achsToleranz * 2 }
            if doppelt == false { akzeptiert.append((r.kandidat, r.quer)) }
            if akzeptiert.count >= maxProAchse { break }
        }
        return akzeptiert.map(\.kandidat)
    }

    public static func hauptkanten(ausPunkten points: [BildPunkt],
                                   mindestSpanne: Double = 0.15,
                                   achsToleranz: Double = 0.05) -> [Kandidat] {
        [Achse.horizontal, .vertikal].compactMap {
            dominanteSpanne(points, achse: $0, mindestSpanne: mindestSpanne, achsToleranz: achsToleranz)
        }
    }

    static func dominanteSpanne(_ points: [BildPunkt], achse: Achse,
                                mindestSpanne: Double, achsToleranz: Double) -> Kandidat? {
        guard points.count >= 2 else { return nil }
        var beste: (a: BildPunkt, b: BildPunkt, laenge: Double)?
        for i in 0..<(points.count - 1) {
            for j in (i + 1)..<points.count {
                let p = points[i], q = points[j]
                let dx = abs(p.x - q.x), dy = abs(p.y - q.y)
                let (laengs, quer) = achse == .horizontal ? (dx, dy) : (dy, dx)
                guard quer <= achsToleranz, laengs >= mindestSpanne else { continue }
                if laengs > (beste?.laenge ?? 0) { beste = (p, q, laengs) }
            }
        }
        guard let b = beste else { return nil }

        let line: BildLinie
        switch achse {
        case .horizontal:
            let y = (b.a.y + b.b.y) / 2
            let (links, rechts) = b.a.x <= b.b.x ? (b.a.x, b.b.x) : (b.b.x, b.a.x)
            line = BildLinie(start: BildPunkt(x: links, y: y), ende: BildPunkt(x: rechts, y: y))
        case .vertikal:
            let x = (b.a.x + b.b.x) / 2
            let (oben, unten) = b.a.y <= b.b.y ? (b.a.y, b.b.y) : (b.b.y, b.a.y)
            line = BildLinie(start: BildPunkt(x: x, y: oben), ende: BildPunkt(x: x, y: unten))
        }
        return Kandidat(line: line, achse: achse)
    }
}
