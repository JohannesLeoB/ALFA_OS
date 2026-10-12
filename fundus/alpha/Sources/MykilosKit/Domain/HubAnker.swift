import Foundation

public struct HubPunkt: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

public struct HubVektor: Equatable, Sendable {
    public var dx: Double
    public var dy: Double
    public init(dx: Double, dy: Double) { self.dx = dx; self.dy = dy }
    public static let null = HubVektor(dx: 0, dy: 0)
    var laenge: Double { (dx * dx + dy * dy).squareRoot() }
}

public struct HubFlaeche: Equatable, Sendable {
    public var width: Double
    public var height: Double
    public init(width: Double, height: Double) { self.width = width; self.height = height }
}

public enum HubAnker: String, Codable, CaseIterable, Sendable {
    case obenRechts, oben, links, untenLinks, unten, untenRechts, rechts

    public var label: String {
        switch self {
        case .obenRechts:  return "oben rechts"
        case .oben:        return "oben"
        case .links:       return "links"
        case .untenLinks:  return "unten links"
        case .unten:       return "unten"
        case .untenRechts: return "unten rechts"
        case .rechts:      return "rechts"
        }
    }

    var relativ: (x: Double, y: Double) {
        switch self {
        case .obenRechts:  return (1, 0)
        case .oben:        return (0.5, 0)
        case .links:       return (0, 0.5)
        case .untenLinks:  return (0, 1)
        case .unten:       return (0.5, 1)
        case .untenRechts: return (1, 1)
        case .rechts:      return (1, 0.5)
        }
    }
}

public enum HubPhysik {
    public static let randAbstand: Double = 24

    public static func ankerEinzug(hubSize: Double) -> Double {
        randAbstand + hubSize / 2
    }

    public static let einrastNaehe: Double = 48

    public static let loeseSchwelle: Double = 80

    public static let bremsung: Double = 0.75

    public static let schwungFaktor: Double = 0.18

    public static func position(_ anker: HubAnker, in surface: HubFlaeche,
                                randAbstand: Double = randAbstand) -> HubPunkt {
        let width = surface.width - randAbstand * 2
        let height = surface.height - randAbstand * 2

        guard width > 0, height > 0 else {
            return HubPunkt(x: surface.width / 2, y: surface.height / 2)
        }
        let r = anker.relativ
        return HubPunkt(x: randAbstand + width * r.x, y: randAbstand + height * r.y)
    }

    public static func naechsterAnker(zu point: HubPunkt, in surface: HubFlaeche,
                                      naehe: Double = einrastNaehe,
                                      randAbstand: Double = randAbstand) -> HubAnker? {
        var bester: (anker: HubAnker, spacing: Double)?
        for anker in HubAnker.allCases {
            let p = position(anker, in: surface, randAbstand: randAbstand)
            let d = HubVektor(dx: point.x - p.x, dy: point.y - p.y).laenge
            if bester == nil || d < bester!.spacing { bester = (anker, d) }
        }
        guard let bester, bester.spacing <= naehe else { return nil }
        return bester.anker
    }

    public static func gebremsterVersatz(_ versatz: HubVektor,
                                         schwelle: Double = loeseSchwelle,
                                         bremsung: Double = bremsung) -> HubVektor {
        let weg = versatz.laenge
        guard weg > 0 else { return .null }

        guard weg < schwelle else { return versatz }

        let anteil = weg / schwelle
        let faktor = 1 - bremsung * (1 - anteil)
        return HubVektor(dx: versatz.dx * faktor, dy: versatz.dy * faktor)
    }

    public static func istGeloest(_ versatz: HubVektor, schwelle: Double = loeseSchwelle) -> Bool {
        versatz.laenge >= schwelle
    }

    public static func ruhelage(losgelassenBei point: HubPunkt, geschwindigkeit: HubVektor,
                               in surface: HubFlaeche, naehe: Double = einrastNaehe,
                               randAbstand: Double = randAbstand)
    -> (point: HubPunkt, anker: HubAnker?) {
        let roh = HubPunkt(x: point.x + geschwindigkeit.dx * schwungFaktor,
                           y: point.y + geschwindigkeit.dy * schwungFaktor)

        let geflogen = imBereich(roh, surface: surface, randAbstand: randAbstand)
        if let anker = naechsterAnker(zu: geflogen, in: surface, naehe: naehe, randAbstand: randAbstand) {
            return (position(anker, in: surface, randAbstand: randAbstand), anker)
        }
        return (geflogen, nil)
    }

    public static func imBereich(_ point: HubPunkt, surface: HubFlaeche,
                                 randAbstand: Double = randAbstand) -> HubPunkt {
        let maxX = surface.width - randAbstand
        let maxY = surface.height - randAbstand
        guard maxX > randAbstand, maxY > randAbstand else {
            return HubPunkt(x: surface.width / 2, y: surface.height / 2)
        }
        return HubPunkt(x: min(max(point.x, randAbstand), maxX),
                        y: min(max(point.y, randAbstand), maxY))
    }
}
