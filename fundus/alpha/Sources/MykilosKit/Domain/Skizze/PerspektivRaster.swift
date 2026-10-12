import Foundation

public struct RasterPunkt: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public enum PerspektivArt: String, Codable, CaseIterable, Sendable {
    case einPunkt, zweiPunkt, dreiPunkt

    public var label: String {
        switch self {
        case .einPunkt:  return "1-Punkt"
        case .zweiPunkt: return "2-Punkt"
        case .dreiPunkt: return "3-Punkt"
        }
    }

    public var anzahlFluchtpunkte: Int {
        switch self {
        case .einPunkt:  return 1
        case .zweiPunkt: return 2
        case .dreiPunkt: return 3
        }
    }
}

public struct PerspektivRaster: Codable, Equatable, Sendable {
    enum CodingKeys: String, CodingKey { case isActive = "aktiv", art, horizontY, fluchtpunkte, strahlenProPunkt, snapAn }

    public var isActive: Bool
    public var art: PerspektivArt
    public var horizontY: Double
    public var fluchtpunkte: [RasterPunkt]

    public var strahlenProPunkt: Int

    public var snapAn: Bool

    public init(isActive: Bool = false, art: PerspektivArt = .zweiPunkt, horizontY: Double = 0.5,
                fluchtpunkte: [RasterPunkt]? = nil, strahlenProPunkt: Int = 24, snapAn: Bool = true) {
        self.isActive = isActive
        self.art = art
        self.horizontY = horizontY
        self.fluchtpunkte = fluchtpunkte ?? Self.standardFluchtpunkte(art: art, horizontY: horizontY)
        self.strahlenProPunkt = max(4, strahlenProPunkt)
        self.snapAn = snapAn
    }

    public static func standardFluchtpunkte(art: PerspektivArt, horizontY: Double) -> [RasterPunkt] {
        switch art {
        case .einPunkt:
            return [RasterPunkt(x: 0.5, y: horizontY)]
        case .zweiPunkt:
            return [RasterPunkt(x: -0.6, y: horizontY), RasterPunkt(x: 1.6, y: horizontY)]
        case .dreiPunkt:
            return [RasterPunkt(x: -0.6, y: horizontY), RasterPunkt(x: 1.6, y: horizontY),
                    RasterPunkt(x: 0.5, y: 3.2)]
        }
    }

    public mutating func setzeArt(_ neu: PerspektivArt) {
        let standard = Self.standardFluchtpunkte(art: neu, horizontY: horizontY)
        var behalten = Array(fluchtpunkte.prefix(neu.anzahlFluchtpunkte))
        while behalten.count < neu.anzahlFluchtpunkte {
            behalten.append(standard[behalten.count])
        }
        art = neu
        fluchtpunkte = behalten
    }

    public mutating func setzeHorizont(_ y: Double) {
        horizontY = y
        let aufHorizont = min(fluchtpunkte.count, 2)
        for i in 0..<aufHorizont { fluchtpunkte[i].y = y }
    }
}

public enum PerspektivGeometrie {
    public static func randZiele(count: Int) -> [RasterPunkt] {
        let n = max(4, count)
        return (0..<n).map { i in

            let t = Double(i) * 4 / Double(n)
            switch Int(t) {
            case 0:  return RasterPunkt(x: t, y: 0)
            case 1:  return RasterPunkt(x: 1, y: t - 1)
            case 2:  return RasterPunkt(x: 3 - t, y: 1)
            default: return RasterPunkt(x: 0, y: 4 - t)
            }
        }
    }

    public static func winkelZu(fluchtpunkt f: RasterPunkt, point p: RasterPunkt, aspekt: Double) -> Double {
        let dx = (p.x - f.x) * max(aspekt, 0.0001)
        let dy = p.y - f.y
        guard dx != 0 || dy != 0 else { return 0 }
        let roh = atan2(dy, dx)
        return normalisiert(roh)
    }

    public static func normalisiert(_ angle: Double) -> Double {
        var w = angle.truncatingRemainder(dividingBy: .pi)
        if w < 0 { w += .pi }
        return w
    }

    public static func winkelAbstand(_ a: Double, _ b: Double) -> Double {
        let d = abs(normalisiert(a) - normalisiert(b))
        return min(d, .pi - d)
    }

    public static func eingerastetesEnde(start: RasterPunkt, ende: RasterPunkt,
                                         grid: PerspektivRaster, aspekt: Double,
                                         toleranzGrad: Double = 7) -> RasterPunkt? {
        guard grid.isActive, grid.snapAn, grid.fluchtpunkte.isEmpty == false else { return nil }
        let a = max(aspekt, 0.0001)
        let linienWinkel = winkelZu(fluchtpunkt: start, point: ende, aspekt: a)
        let toleranz = toleranzGrad * .pi / 180

        var bester: (point: RasterPunkt, abweichung: Double)?
        for f in grid.fluchtpunkte {
            let strahlWinkel = winkelZu(fluchtpunkt: f, point: start, aspekt: a)
            let abweichung = winkelAbstand(linienWinkel, strahlWinkel)
            guard abweichung <= toleranz else { continue }
            guard let projiziert = projiziereAufStrahl(start: start, durch: f, ende: ende, aspekt: a) else { continue }
            if bester == nil || abweichung < bester!.abweichung {
                bester = (projiziert, abweichung)
            }
        }
        return bester?.point
    }

    public static func projiziereAufStrahl(start: RasterPunkt, durch f: RasterPunkt,
                                           ende: RasterPunkt, aspekt: Double) -> RasterPunkt? {
        let a = max(aspekt, 0.0001)

        let sx = start.x * a, sy = start.y
        let fx = f.x * a, fy = f.y
        let ex = ende.x * a, ey = ende.y
        let rx = fx - sx, ry = fy - sy
        let laengeQuadrat = rx * rx + ry * ry
        guard laengeQuadrat > 0 else { return nil }
        let t = ((ex - sx) * rx + (ey - sy) * ry) / laengeQuadrat
        return RasterPunkt(x: (sx + rx * t) / a, y: sy + ry * t)
    }

    public static func strahlenZumBild(fluchtpunkt f: RasterPunkt, count: Int,
                                       ueberstand: Double = 1.03)
    -> [(von: RasterPunkt, bis: RasterPunkt)] {
        randZiele(count: count).map { target in
            (f, RasterPunkt(x: f.x + (target.x - f.x) * ueberstand,
                            y: f.y + (target.y - f.y) * ueberstand))
        }
    }
}
