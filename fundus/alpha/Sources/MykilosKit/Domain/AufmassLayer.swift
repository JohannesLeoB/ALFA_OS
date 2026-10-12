import Foundation
import CryptoKit

public struct AufmassLayer: Identifiable, Codable, Equatable, Sendable {
    enum CodingKeys: String, CodingKey { case id, name, color = "farbe", isVisible = "sichtbar", fontSize = "schriftgroesse" }

    public let id: String
    public var name: String

    public var color: String
    public var isVisible: Bool

    public var fontSize: Double

    public init(id: String, name: String, color: String, isVisible: Bool = true, fontSize: Double = 9) {
        self.id = id
        self.name = name
        self.color = color
        self.isVisible = isVisible
        self.fontSize = fontSize
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        color = Self.currentColorID(try c.decode(String.self, forKey: .color))
        isVisible = try c.decode(Bool.self, forKey: .isVisible)
        fontSize = try c.decodeIfPresent(Double.self, forKey: .fontSize) ?? 9
    }

    public static func istHexFarbe(_ value: String) -> Bool {
        value.hasPrefix("#")
    }

    public static func hexKomponenten(_ hex: String) -> (r: Double, g: Double, b: Double)? {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let value = UInt32(h, radix: 16) else { return nil }
        return (
            Double((value >> 16) & 0xFF) / 255,
            Double((value >> 8) & 0xFF) / 255,
            Double(value & 0xFF) / 255
        )
    }

    public static func standardSatz() -> [AufmassLayer] {
        [
            AufmassLayer(id: "layer-gesamt", name: "Gesamtmaße", color: "critical"),
            AufmassLayer(id: "layer-installation", name: "Wasser/Installation", color: "cash"),
            AufmassLayer(id: "layer-details", name: "Details", color: "positive")
        ]
    }

    public static let farbPalette: [String] = [
        "critical", "cash", "positive", "drive", "tasks",
        "personal", "team1", "team2", "team3", "brand"
    ]

    static let replacedColorIDs: [String: String] = [
        "98beda9944909500": "team1",
        "985c107319605dac": "team2",
        "1d0446e3c3d7af65": "team3"
    ]

    static func currentColorID(_ id: String) -> String {
        let digest = SHA256.hash(data: Data(id.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
        return replacedColorIDs[digest] ?? id
    }

    public static var maxLayer: Int { farbPalette.count }

    public static func naechsteFreieFarbe(vorhandene: [AufmassLayer]) -> String {
        let belegt = Set(vorhandene.map(\.color))
        return farbPalette.first { !belegt.contains($0) } ?? farbPalette[vorhandene.count % farbPalette.count]
    }

    public static func neu(name: String, vorhandene: [AufmassLayer], color: String? = nil) -> AufmassLayer {
        let sauber = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalerName = sauber.isEmpty ? "Layer \(vorhandene.count + 1)" : sauber
        let finaleFarbe = color ?? naechsteFreieFarbe(vorhandene: vorhandene)
        return AufmassLayer(id: "layer-\(UUID().uuidString.prefix(8))", name: finalerName, color: finaleFarbe)
    }
}

public enum LinienStil: String, Codable, CaseIterable, Sendable {
    case duenn, normal, gestrichelt, punktiert

    public var width: Double {
        switch self {
        case .duenn: return 1
        case .normal: return 2
        case .gestrichelt: return 1.5
        case .punktiert: return 1.5
        }
    }

    public var patterns: [Double]? {
        switch self {
        case .duenn, .normal: return nil
        case .gestrichelt: return [6, 4]
        case .punktiert: return [1.5, 4]
        }
    }
    public var label: String {
        switch self {
        case .duenn: return "Dünn"
        case .normal: return "Normal"
        case .gestrichelt: return "Gestrichelt"
        case .punktiert: return "Punktiert"
        }
    }
}

public enum InstallationsTyp: String, Codable, CaseIterable, Sendable {
    case wasser, abwasser, gas, strom, steckdose, netzwerk, heizung, lueftung, lautsprecher, geraet, anschluss

    public var symbol: String {
        switch self {
        case .wasser:      return "drop.fill"
        case .abwasser:    return "drop.triangle"
        case .gas:         return "flame.fill"
        case .strom:       return "bolt.fill"
        case .steckdose:   return "poweroutlet.type.f.fill"
        case .netzwerk:    return "network"
        case .heizung:     return "thermometer.medium"
        case .lueftung:    return "wind"
        case .lautsprecher: return "hifispeaker.fill"
        case .geraet:      return "cube.box.fill"
        case .anschluss:   return "point.3.connected.trianglepath.dotted"
        }
    }
    public var label: String {
        switch self {
        case .wasser:      return "Wasser"
        case .abwasser:    return "Abwasser"
        case .gas:         return "Gas"
        case .strom:       return "Strom"
        case .steckdose:   return "Steckdose"
        case .netzwerk:    return "Netzwerk"
        case .heizung:     return "Heizung"
        case .lueftung:    return "Lüftung"
        case .lautsprecher: return "Lautsprecher"
        case .geraet:      return "Gerät"
        case .anschluss:   return "Anschluss"
        }
    }
}

public struct AufmassSymbol: Identifiable, Codable, Equatable, Sendable {
    enum CodingKeys: String, CodingKey { case id, typ, position, layerID, notiz, photoId = "fotoID" }

    public let id: String
    public var typ: InstallationsTyp
    public var position: BildPunkt
    public var layerID: String
    public var notiz: String?
    public var photoId: String?

    public init(id: String, typ: InstallationsTyp, position: BildPunkt,
                layerID: String, notiz: String? = nil, photoId: String? = nil) {
        self.id = id
        self.typ = typ
        self.position = position
        self.layerID = layerID
        self.photoId = photoId
        self.notiz = notiz
    }
}

public enum AufmassTreffer {
    public static func naechsterPunkt(_ points: [BildPunkt], zu target: BildPunkt,
                                      aspekt: Double, radiusNorm: Double) -> Int? {
        var bester: (idx: Int, dist: Double)?
        for (i, p) in points.enumerated() {
            let dx = (p.x - target.x) * aspekt
            let dy = (p.y - target.y)
            let d = (dx * dx + dy * dy).squareRoot()
            if d <= radiusNorm, d < (bester?.dist ?? .greatestFiniteMagnitude) { bester = (i, d) }
        }
        return bester?.idx
    }
}

public struct AufmassPin: Identifiable, Codable, Equatable, Sendable {
    enum CodingKeys: String, CodingKey { case id, position, text, layerID, photoId = "fotoID" }

    public let id: String
    public var position: BildPunkt
    public var text: String
    public var layerID: String
    public var photoId: String?

    public init(id: String, position: BildPunkt, text: String, layerID: String, photoId: String? = nil) {
        self.id = id
        self.position = position
        self.text = text
        self.layerID = layerID
        self.photoId = photoId
    }
}
