import Foundation

public struct LabFarbe: Equatable, Sendable, Codable {
    public let L: Double

    public let a: Double

    public let b: Double

    public init(L: Double, a: Double, b: Double) {
        self.L = L
        self.a = a
        self.b = b
    }

    public var chroma: Double { (a * a + b * b).squareRoot() }

    public var buntton: Double {
        guard chroma > 1e-9 else { return 0 }
        let grad = atan2(b, a) * 180 / .pi
        return grad < 0 ? grad + 360 : grad
    }

    public var kurzform: String {
        String(format: "L %.1f · a %.1f · b %.1f", L, a, b)
    }
}

public struct SRGBFarbe: Equatable, Sendable, Codable {
    public let r: Double
    public let g: Double
    public let b: Double

    public init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    public var istImGamut: Bool {
        let toleranz = 0.0005
        return [r, g, b].allSatisfy { $0 >= -toleranz && $0 <= 1 + toleranz }
    }

    public var beschnitten: SRGBFarbe {
        SRGBFarbe(r: min(max(r, 0), 1), g: min(max(g, 0), 1), b: min(max(b, 0), 1))
    }

    public var hex: String {
        let c = beschnitten
        let acht = { (value: Double) -> Int in Int((value * 255).rounded()) }
        return String(format: "#%02X%02X%02X", acht(c.r), acht(c.g), acht(c.b))
    }

    public static func vonHex(_ text: String) -> SRGBFarbe? {
        var roh = text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if roh.hasPrefix("#") { roh.removeFirst() }
        if roh.count == 3 {
            roh = roh.map { "\($0)\($0)" }.joined()
        }
        guard roh.count == 6, let zahl = Int(roh, radix: 16) else { return nil }
        return SRGBFarbe(
            r: Double((zahl >> 16) & 0xFF) / 255,
            g: Double((zahl >> 8) & 0xFF) / 255,
            b: Double(zahl & 0xFF) / 255
        )
    }
}

public enum FarbRaum {
    public static let weissD65 = (x: 0.95047, y: 1.0, z: 1.08883)

    public static func labVonSRGB(_ color: SRGBFarbe) -> LabFarbe {
        let rl = linear(color.r), gl = linear(color.g), bl = linear(color.b)

        let x = 0.4124564 * rl + 0.3575761 * gl + 0.1804375 * bl
        let y = 0.2126729 * rl + 0.7151522 * gl + 0.0721750 * bl
        let z = 0.0193339 * rl + 0.1191920 * gl + 0.9503041 * bl
        return labVonXYZ(x: x, y: y, z: z)
    }

    public static func labVonXYZ(x: Double, y: Double, z: Double) -> LabFarbe {
        let fx = f(x / weissD65.x), fy = f(y / weissD65.y), fz = f(z / weissD65.z)
        return LabFarbe(L: 116 * fy - 16, a: 500 * (fx - fy), b: 200 * (fy - fz))
    }

    public static func sRGBVonLab(_ lab: LabFarbe) -> SRGBFarbe {
        let (x, y, z) = xyzVonLab(lab)

        let rl = 3.2404542 * x - 1.5371385 * y - 0.4985314 * z
        let gl = -0.9692660 * x + 1.8760108 * y + 0.0415560 * z
        let bl = 0.0556434 * x - 0.2040259 * y + 1.0572252 * z
        return SRGBFarbe(r: gamma(rl), g: gamma(gl), b: gamma(bl))
    }

    public static func xyzVonLab(_ lab: LabFarbe) -> (x: Double, y: Double, z: Double) {
        let fy = (lab.L + 16) / 116
        let fx = fy + lab.a / 500
        let fz = fy - lab.b / 200
        return (fUmkehr(fx) * weissD65.x, fUmkehr(fy) * weissD65.y, fUmkehr(fz) * weissD65.z)
    }

    private static let delta = 6.0 / 29.0

    private static func f(_ t: Double) -> Double {
        t > delta * delta * delta ? cbrt(t) : t / (3 * delta * delta) + 4.0 / 29.0
    }

    private static func fUmkehr(_ t: Double) -> Double {
        t > delta ? t * t * t : 3 * delta * delta * (t - 4.0 / 29.0)
    }

    private static func linear(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    private static func gamma(_ c: Double) -> Double {
        c <= 0.0031308 ? 12.92 * c : 1.055 * pow(c, 1 / 2.4) - 0.055
    }
}

public enum FarbAbstand {
    public static func deltaE76(_ eins: LabFarbe, _ zwei: LabFarbe) -> Double {
        let dL = eins.L - zwei.L, da = eins.a - zwei.a, db = eins.b - zwei.b
        return (dL * dL + da * da + db * db).squareRoot()
    }

    public static func deltaE2000(_ eins: LabFarbe, _ zwei: LabFarbe) -> Double {
        let bogen = Double.pi / 180

        let c1 = eins.chroma, c2 = zwei.chroma
        let cMittel = (c1 + c2) / 2
        let c7 = pow(cMittel, 7)
        let g = 0.5 * (1 - (c7 / (c7 + pow(25, 7))).squareRoot())

        let a1s = (1 + g) * eins.a, a2s = (1 + g) * zwei.a
        let c1s = (a1s * a1s + eins.b * eins.b).squareRoot()
        let c2s = (a2s * a2s + zwei.b * zwei.b).squareRoot()

        let h1s = buntton(a: a1s, b: eins.b)
        let h2s = buntton(a: a2s, b: zwei.b)

        let dL = zwei.L - eins.L
        let dC = c2s - c1s

        var dh = 0.0
        if c1s * c2s != 0 {
            dh = h2s - h1s
            if dh > 180 { dh -= 360 } else if dh < -180 { dh += 360 }
        }
        let dH = 2 * (c1s * c2s).squareRoot() * sin(dh / 2 * bogen)

        let lMittel = (eins.L + zwei.L) / 2
        let cMittelS = (c1s + c2s) / 2

        var hMittel = h1s + h2s
        if c1s * c2s != 0 {
            if abs(h1s - h2s) <= 180 {
                hMittel = (h1s + h2s) / 2
            } else if h1s + h2s < 360 {
                hMittel = (h1s + h2s + 360) / 2
            } else {
                hMittel = (h1s + h2s - 360) / 2
            }
        }

        let t = 1
            - 0.17 * cos((hMittel - 30) * bogen)
            + 0.24 * cos((2 * hMittel) * bogen)
            + 0.32 * cos((3 * hMittel + 6) * bogen)
            - 0.20 * cos((4 * hMittel - 63) * bogen)

        let dTheta = 30 * exp(-pow((hMittel - 275) / 25, 2))
        let cs7 = pow(cMittelS, 7)
        let rC = 2 * (cs7 / (cs7 + pow(25, 7))).squareRoot()

        let sL = 1 + (0.015 * pow(lMittel - 50, 2)) / (20 + pow(lMittel - 50, 2)).squareRoot()
        let sC = 1 + 0.045 * cMittelS
        let sH = 1 + 0.015 * cMittelS * t
        let rT = -sin(2 * dTheta * bogen) * rC

        let tL = dL / sL, tC = dC / sC, tH = dH / sH
        return (tL * tL + tC * tC + tH * tH + rT * tC * tH).squareRoot()
    }

    private static func buntton(a: Double, b: Double) -> Double {
        guard a != 0 || b != 0 else { return 0 }
        let grad = atan2(b, a) * 180 / .pi
        return grad < 0 ? grad + 360 : grad
    }

    public static func einordnung(_ deltaE: Double) -> String {
        switch deltaE {
        case ..<1.0:  "praktisch identisch"
        case ..<2.0:  "nur im direkten Vergleich unterscheidbar"
        case ..<3.5:  "sichtbarer Unterschied"
        case ..<5.0:  "deutlich anderer Ton"
        default:      "andere Farbe"
        }
    }
}

public struct Farbeintrag: Identifiable, Equatable, Sendable, Codable {
    public let id: UUID

    public var name: String

    public var sammlung: String
    public var lab: LabFarbe

    public var herkunft: FarbHerkunft
    public var notiz: String

    public init(id: UUID = UUID(), name: String, sammlung: String = "Studio",
                lab: LabFarbe, herkunft: FarbHerkunft = .handeingabe, notiz: String = "") {
        self.id = id
        self.name = name
        self.sammlung = sammlung
        self.lab = lab
        self.herkunft = herkunft
        self.notiz = notiz
    }

    public var hex: String { FarbRaum.sRGBVonLab(lab).hex }
}

public enum FarbHerkunft: String, Equatable, Sendable, Codable {
    case gemessen

    case handeingabe

    case bildpicker
}

public struct FarbTreffer: Identifiable, Equatable, Sendable {
    public let entry: Farbeintrag
    public let deltaE: Double
    public var id: UUID { entry.id }

    public init(entry: Farbeintrag, deltaE: Double) {
        self.entry = entry
        self.deltaE = deltaE
    }
}

public struct Farbfaecher: Equatable, Sendable, Codable {
    enum CodingKeys: String, CodingKey { case name, entries = "eintraege" }

    public var name: String
    public var entries: [Farbeintrag]

    public init(name: String, entries: [Farbeintrag] = []) {
        self.name = name
        self.entries = entries
    }

    public func naechste(zu lab: LabFarbe, count: Int = 5) -> [FarbTreffer] {
        guard count > 0 else { return [] }
        let match: [FarbTreffer] = entries.map { entry in
            FarbTreffer(entry: entry, deltaE: FarbAbstand.deltaE2000(lab, entry.lab))
        }
        let sortiert: [FarbTreffer] = match.sorted { links, rechts in
            if links.deltaE == rechts.deltaE { return links.entry.name < rechts.entry.name }
            return links.deltaE < rechts.deltaE
        }
        return Array(sortiert.prefix(count))
    }
}

public struct FarbMessung: Identifiable, Equatable, Sendable, Codable {
    public let id: UUID
    public let zeitpunkt: Date
    public let lab: LabFarbe

    public let geraet: String
    public var notiz: String

    public init(id: UUID = UUID(), zeitpunkt: Date, lab: LabFarbe,
                geraet: String, notiz: String = "") {
        self.id = id
        self.zeitpunkt = zeitpunkt
        self.lab = lab
        self.geraet = geraet
        self.notiz = notiz
    }

    public var hex: String { FarbRaum.sRGBVonLab(lab).hex }
}

public protocol FarbMessend: Sendable {
    var status: AsyncStream<FarbVerbindungsStatus> { get }
    var letzteMessung: AsyncStream<FarbMessung> { get }
    func verbinde() async throws
    func trenne() async
}

public enum FarbVerbindungsStatus: Equatable, Sendable {
    case getrennt
    case sucht
    case gekoppelt(geraetename: String)
    case error(String)
}
