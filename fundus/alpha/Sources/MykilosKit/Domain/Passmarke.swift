import Foundation

public enum PassmarkeZustand: String, CaseIterable, Sendable, Equatable {
    case geparkt

    case sehnend

    case offen

    case ziehend

    case frei

    case gehend

    public var dockDarfErscheinen: Bool {
        switch self {
        case .frei: false
        case .ziehend: true
        case .geparkt, .sehnend, .offen, .gehend: true
        }
    }

    public var darfSehnen: Bool { self == .geparkt }
}

public enum PassmarkeHeimseite: String, Codable, CaseIterable, Sendable {
    case unten, links, rechts

    public var label: String {
        switch self {
        case .unten: "unten"
        case .links: "links"
        case .rechts: "rechts"
        }
    }

    public var istSenkrecht: Bool { self != .unten }
}

public enum PassmarkeMass {
    public static let size: Double = 56

    public static let radius: Double = 18

    public static let sehnRadius: Double = 190

    public static let sehnWeg: Double = 9

    public static let sehnDrehung: Double = 7

    public static let kantenSuche: Double = 26

    public static let fangzone: Double = 108

    public static let rufFenster: TimeInterval = 0.340
    public static let rufWechsel: Int = 4

    public static let heimVerzug: TimeInterval = 0.420

    public static let ankerToleranz: Double = 4

    public static let doppelklick: TimeInterval = 0.320

    public static let spurTiefe: Int = 5
}

public enum PassmarkeHeimplatz {
    public static func anker(_ page: PassmarkeHeimseite,
                            width: Double, height: Double) -> (x: Double, y: Double) {
        switch page {
        case .unten:  (x: width / 2 - 28, y: height - 84)
        case .links:  (x: 20, y: height / 2 - 28)
        case .rechts: (x: width - 76, y: height / 2 - 28)
        }
    }

    public static func fangzone(fuer x: Double, y: Double,
                                width: Double, height: Double) -> PassmarkeHeimseite? {
        let mulde = anker(.unten, width: width, height: height)
        let zurMulde = ((x - mulde.x) * (x - mulde.x) + (y - mulde.y) * (y - mulde.y)).squareRoot()

        var match: [(PassmarkeHeimseite, Double)] = []
        if zurMulde <= PassmarkeMass.fangzone { match.append((.unten, zurMulde)) }
        if x <= PassmarkeMass.fangzone { match.append((.links, x)) }
        if width - x <= PassmarkeMass.fangzone { match.append((.rechts, width - x)) }
        return match.min(by: { $0.1 < $1.1 })?.0
    }
}

public enum PassmarkeSehnen {
    public static func lehnung(status: PassmarkeZustand,
                               knopfX: Double, knopfY: Double,
                               zeigerX: Double, zeigerY: Double)
    -> (dx: Double, dy: Double, drehung: Double, naehe: Double)? {
        guard status.darfSehnen else { return nil }
        let dx = zeigerX - knopfX, dy = zeigerY - knopfY
        let spacing = (dx * dx + dy * dy).squareRoot()
        guard spacing > 0, spacing <= PassmarkeMass.sehnRadius else { return nil }
        let naehe = 1 - spacing / PassmarkeMass.sehnRadius
        let weg = PassmarkeMass.sehnWeg * naehe * naehe
        return (dx: dx / spacing * weg,
                dy: dy / spacing * weg,
                drehung: PassmarkeMass.sehnDrehung * naehe * naehe,
                naehe: naehe)
    }

    public static let zappelSchwelle: Double = 0.45
    public static let zappelPause: TimeInterval = 0.620
}

public enum PassmarkeGang {
    public static func dauer(weg: Double) -> TimeInterval {
        min(0.92, max(0.36, 0.28 + weg / 1500))
    }

    public static func schritte(weg: Double) -> Int {
        max(1, Int((dauer(weg: weg) * 9).rounded(.down)))
    }

    public static func takt(weg: Double) -> TimeInterval {
        dauer(weg: weg) / Double(schritte(weg: weg) * 2)
    }

    public static let anlauf: TimeInterval = 0.100
    public static let ankunft: TimeInterval = 0.560
}

public struct PassmarkeModell: Sendable, Equatable {
    public private(set) var status: PassmarkeZustand
    public private(set) var heimseite: PassmarkeHeimseite

    public private(set) var spur: [String]

    public init(status: PassmarkeZustand = .geparkt,
                heimseite: PassmarkeHeimseite = .unten,
                spur: [String] = []) {
        self.status = status
        self.heimseite = heimseite
        self.spur = spur
    }

    public mutating func handAufgesetzt() { status = .ziehend }

    public mutating func losgelassen(in zone: PassmarkeHeimseite?) {
        guard status == .ziehend else { return }
        if let zone {
            heimseite = zone
            status = .geparkt
        } else {
            status = .frei
        }
    }

    public mutating func gerufen() {
        guard status != .ziehend else { return }
        status = .gehend
    }

    public mutating func zeigerNah() {
        if status == .geparkt { status = .sehnend }
    }

    public mutating func zeigerFern() {
        if status == .sehnend { status = .geparkt }
    }

    public mutating func wolkeGeoeffnet() {
        guard status == .geparkt || status == .sehnend || status == .frei else { return }
        status = .offen
    }

    public mutating func wolkeGeschlossen() {
        if status == .offen { status = .geparkt }
    }

    public mutating func heimGeschickt() {
        guard status != .ziehend else { return }
        status = .gehend
    }

    public mutating func angekommen() {
        if status == .gehend { status = .geparkt }
    }

    public mutating func bereichVerlassen(_ area: String) {
        guard spur.last != area else { return }
        spur.append(area)
        if spur.count > PassmarkeMass.spurTiefe { spur.removeFirst(spur.count - PassmarkeMass.spurTiefe) }
    }

    public mutating func zurueck() -> String? {
        guard !spur.isEmpty else { return nil }
        return spur.removeLast()
    }

    public var hatWegZurueck: Bool { !spur.isEmpty }
}

public struct PassmarkeRufkenner: Sendable, Equatable {
    private var wechsel: [TimeInterval] = []

    private var richtung: Int = 0

    public static let mindestWeg: Double = 12

    public init() {}

    public mutating func bewegt(dx: Double, zeit: TimeInterval) -> Bool {
        guard abs(dx) >= Self.mindestWeg else { return false }
        let neu = dx < 0 ? -1 : 1

        guard richtung != 0, neu != richtung else {
            richtung = neu
            return false
        }

        richtung = neu
        wechsel.append(zeit)

        wechsel.removeAll { zeit - $0 > PassmarkeMass.rufFenster }
        if wechsel.count >= PassmarkeMass.rufWechsel {
            wechsel.removeAll()
            richtung = 0
            return true
        }
        return false
    }

    public mutating func vergessen() {
        wechsel.removeAll()
        richtung = 0
    }

    public var angefangeneWechsel: Int { wechsel.count }
}

public enum PassmarkeWolke {
    public static let radius: Double = 84

    public static let zielwechsel: Double = 62

    public static let korridor: Double = 52

    public static let maxMassstab: Double = 1.45

    public static let faecherDauer: TimeInterval = 0.660
    public static let faecherVersatz: TimeInterval = 0.028
    public static let wolkeAuf: TimeInterval = 0.620

    public static let einsammeln: TimeInterval = 0.260
    public static let wolkeZu: TimeInterval = 0.340
    public static let knopfZurueck: TimeInterval = 0.420

    public static func massstab(spacing: Double, hoeheImOverlay: Double) -> Double {
        guard hoeheImOverlay > korridor else { return 1 }
        guard spacing < radius else { return 1 }
        let naehe = 1 - spacing / radius

        return 1 + (maxMassstab - 1) * naehe * naehe
    }

    public static func verzug(index: Int) -> TimeInterval {
        Double(index) * faecherVersatz
    }
}

public enum PassmarkeKueken {
    public static func folgen(status: PassmarkeZustand, wolkeOffen: Bool) -> Bool {
        status == .ziehend && wolkeOffen
    }

    public static func traegheit(index: Int) -> Double {
        max(0.02, 0.135 - Double(index) * 0.012)
    }

    public static func neigung(geschwindigkeit: Double) -> Double {
        let anteil = max(-1, min(1, geschwindigkeit / 600))
        return 11 * anteil
    }
}

public struct PassmarkeLernen: Sendable, Equatable {
    private var zaehler: [String: Int]

    public var isActive: Bool

    public static let spitzenreiter = 3
    public static let fachGross: Double = 52
    public static let fachNormal: Double = 46

    public init(zaehler: [String: Int] = [:], isActive: Bool = true) {
        self.zaehler = zaehler
        self.isActive = isActive
    }

    public mutating func benutzt(_ tool: String) {
        zaehler[tool, default: 0] += 1
    }

    public func aufrufe(_ tool: String) -> Int { zaehler[tool] ?? 0 }

    public mutating func vergessen() { zaehler.removeAll() }

    public func geordnet(_ cluster: [String]) -> [String] {
        guard isActive else { return cluster }
        return cluster.enumerated()
            .sorted { links, rechts in
                let a = aufrufe(links.element), b = aufrufe(rechts.element)
                if a != b { return a > b }
                return links.offset < rechts.offset
            }
            .map(\.element)
    }

    public func fachGroesse(_ tool: String) -> Double {
        guard isActive, aufrufe(tool) > 0 else { return Self.fachNormal }
        let spitze = zaehler.filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
            .prefix(Self.spitzenreiter)
            .map(\.key)
        return spitze.contains(tool) ? Self.fachGross : Self.fachNormal
    }
}
