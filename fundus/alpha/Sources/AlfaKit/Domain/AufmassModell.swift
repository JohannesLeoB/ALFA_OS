import Foundation

public enum Masseinheit: String, CaseIterable, Codable, Sendable {
    case mm, cm, m

    public var symbol: String { rawValue }

    public var meterProEinheit: Double {
        switch self {
        case .mm: return 0.001
        case .cm: return 0.01
        case .m:  return 1.0
        }
    }

    public func inMeter(_ value: Double) -> Double { value * meterProEinheit }

    public func vonMeter(_ meter: Double) -> Double { meter / meterProEinheit }

    public func formatiere(_ meter: Double, nachkommastellen: Int? = nil) -> String {
        let value = vonMeter(meter)
        let f = NumberFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.numberStyle = .decimal

        f.usesGroupingSeparator = false

        let defaultStellen = (self == .m) ? 2 : 0
        f.minimumFractionDigits = nachkommastellen ?? defaultStellen
        f.maximumFractionDigits = nachkommastellen ?? defaultStellen
        let zahl = f.string(from: NSNumber(value: value)) ?? String(value)
        return "\(zahl) \(symbol)"
    }
}

public enum Messquelle: String, Codable, Sendable {
    case manuell
    case laser
    case auto
}

public struct BildPunkt: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) {
        self.x = min(max(x, 0), 1)
        self.y = min(max(y, 0), 1)
    }
}

public struct BildLinie: Codable, Equatable, Sendable {
    public var start: BildPunkt
    public var ende: BildPunkt
    public init(start: BildPunkt, ende: BildPunkt) {
        self.start = start
        self.ende = ende
    }

    public var laengeNormiert: Double {
        let dx = ende.x - start.x, dy = ende.y - start.y
        return (dx * dx + dy * dy).squareRoot()
    }
}

public struct AufmassFoto: Identifiable, Codable, Equatable, Sendable {
    enum CodingKeys: String, CodingKey { case id, fileName = "dateiname", width = "breite", height = "hoehe", kalibrierung, title = "titel" }

    public let id: String
    public var fileName: String
    public var width: Int?
    public var height: Int?

    public var kalibrierung: GrundrissKalibrierung?
    public var title: String?
    public init(id: String, fileName: String, width: Int? = nil, height: Int? = nil,
                kalibrierung: GrundrissKalibrierung? = nil, title: String? = nil) {
        self.id = id
        self.fileName = fileName
        self.width = width
        self.height = height
        self.kalibrierung = kalibrierung
        self.title = title
    }
}

public struct GrundrissKalibrierung: Codable, Equatable, Sendable {
    public var meterProBreite: Double
    public var meterProHoehe: Double

    public init(meterProBreite: Double, meterProHoehe: Double) {
        self.meterProBreite = meterProBreite
        self.meterProHoehe = meterProHoehe
    }

    public func laenge(_ line: BildLinie) -> Double {
        let dx = (line.ende.x - line.start.x) * meterProBreite
        let dy = (line.ende.y - line.start.y) * meterProHoehe
        return (dx * dx + dy * dy).squareRoot()
    }

    public static func isotrop(referenz: BildLinie, realMeter: Double) -> GrundrissKalibrierung? {
        let n = referenz.laengeNormiert
        guard n > 0 else { return nil }
        let k = realMeter / n
        return GrundrissKalibrierung(meterProBreite: k, meterProHoehe: k)
    }

    public static func ausXY(referenzX: BildLinie, realMeterX: Double,
                             referenzY: BildLinie, realMeterY: Double) -> GrundrissKalibrierung? {
        let dx = abs(referenzX.ende.x - referenzX.start.x)
        let dy = abs(referenzY.ende.y - referenzY.start.y)
        guard dx > 0, dy > 0 else { return nil }
        return GrundrissKalibrierung(meterProBreite: realMeterX / dx, meterProHoehe: realMeterY / dy)
    }
}

public struct AufmassPosition: Identifiable, Codable, Equatable, Sendable {
    enum CodingKeys: String, CodingKey { case id, label = "bezeichnung", meter, source = "quelle", erfasstAm, photoId = "fotoID", bildLinie, layerID, stil }

    public let id: String
    public var label: String
    public var meter: Double
    public var source: Messquelle
    public var erfasstAm: Date

    public var photoId: String?

    public var bildLinie: BildLinie?

    public var layerID: String?

    public var stil: LinienStil

    public init(id: String, label: String, meter: Double,
                source: Messquelle, erfasstAm: Date,
                photoId: String? = nil, bildLinie: BildLinie? = nil,
                layerID: String? = nil, stil: LinienStil = .duenn) {
        self.id = id
        self.label = label
        self.meter = meter
        self.source = source
        self.erfasstAm = erfasstAm
        self.photoId = photoId
        self.bildLinie = bildLinie
        self.layerID = layerID
        self.stil = stil
    }
}

public struct Aufmass: Identifiable, Codable, Equatable, Sendable {
    enum CodingKeys: String, CodingKey { case id, projectNumber = "projektNummer", title = "titel", positionen, fotos, layers, symbole, pins }

    public let id: String
    public var projectNumber: String
    public var title: String
    public var positionen: [AufmassPosition]

    public var fotos: [AufmassFoto]

    public var layers: [AufmassLayer]

    public var symbole: [AufmassSymbol]

    public var pins: [AufmassPin]

    public init(id: String, projectNumber: String, title: String,
                positionen: [AufmassPosition] = [], fotos: [AufmassFoto] = [],
                layers: [AufmassLayer] = [], symbole: [AufmassSymbol] = [], pins: [AufmassPin] = []) {
        self.id = id
        self.projectNumber = projectNumber
        self.title = title
        self.positionen = positionen
        self.fotos = fotos
        self.layers = layers
        self.symbole = symbole
        self.pins = pins
    }

    public func positionen(fuerFoto photoId: String) -> [AufmassPosition] {
        positionen.filter { $0.photoId == photoId }
    }

    public var sichtbareLayerIDs: Set<String> {
        Set(layers.filter(\.isVisible).map(\.id))
    }

    public func istSichtbar(layerID: String?) -> Bool {
        guard let layerID, layers.contains(where: { $0.id == layerID }) else { return true }
        return sichtbareLayerIDs.contains(layerID)
    }

    public var visiblePositions: [AufmassPosition] {
        positionen.filter { istSichtbar(layerID: $0.layerID) }
    }

    public var sichtbareSymbole: [AufmassSymbol] {
        symbole.filter { istSichtbar(layerID: $0.layerID) }
    }

    public var sichtbarePins: [AufmassPin] {
        pins.filter { istSichtbar(layerID: $0.layerID) }
    }

    public func hinzugefuegt(_ position: AufmassPosition) -> Aufmass {
        var kopie = self
        kopie.positionen.append(position)
        return kopie
    }

    public func layerEntfernt(_ layerID: String) -> Aufmass {
        guard layers.contains(where: { $0.id == layerID }) else { return self }
        var kopie = self
        kopie.layers.removeAll { $0.id == layerID }
        for i in kopie.positionen.indices where kopie.positionen[i].layerID == layerID {
            kopie.positionen[i].layerID = nil
        }
        for i in kopie.symbole.indices where kopie.symbole[i].layerID == layerID {
            kopie.symbole[i].layerID = ""
        }
        for i in kopie.pins.indices where kopie.pins[i].layerID == layerID {
            kopie.pins[i].layerID = ""
        }
        return kopie
    }

    public var gesamtMeter: Double { positionen.reduce(0) { $0 + $1.meter } }

    public func summeMeter(fuerLayer layerID: String?) -> Double {
        positionen.filter { $0.layerID == layerID }.reduce(0) { $0 + $1.meter }
    }

    public func count(fuerLayer layerID: String?) -> Int {
        positionen.filter { $0.layerID == layerID }.count
    }

    public var count: Int { positionen.count }
}

public enum AufmassRechnung {
    public static func flaecheM2(_ laengeMeter: Double, _ breiteMeter: Double) -> Double {
        laengeMeter * breiteMeter
    }

    public static func volumenM3(_ a: Double, _ b: Double, _ c: Double) -> Double {
        a * b * c
    }

    public static func formatiereFlaeche(_ m2: Double, nachkommastellen: Int = 2) -> String {
        einheitenText(m2, symbol: "m²", nachkommastellen: nachkommastellen)
    }

    public static func formatiereVolumen(_ m3: Double, nachkommastellen: Int = 2) -> String {
        einheitenText(m3, symbol: "m³", nachkommastellen: nachkommastellen)
    }

    private static func einheitenText(_ value: Double, symbol: String, nachkommastellen: Int) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.numberStyle = .decimal
        f.minimumFractionDigits = nachkommastellen
        f.maximumFractionDigits = nachkommastellen
        let zahl = f.string(from: NSNumber(value: value)) ?? String(value)
        return "\(zahl) \(symbol)"
    }
}
