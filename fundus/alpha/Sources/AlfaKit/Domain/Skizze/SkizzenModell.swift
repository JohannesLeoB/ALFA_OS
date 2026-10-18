import Foundation

public enum FotoQuelle: Codable, Equatable, Sendable {
    case lokalerPfad(String)
    case driveDatei(String)
    case eingebettet

    public var kurzname: String {
        switch self {
        case let .lokalerPfad(pfad):
            let file = pfad.split(separator: "/").last.map(String.init) ?? pfad
            let ohneEndung = file.split(separator: ".").dropLast()
            return ohneEndung.isEmpty ? file : ohneEndung.joined(separator: ".")
        case .driveDatei:
            return "Drive"
        case .eingebettet:
            return "Eingebettet"
        }
    }
}

public struct FotoReferenz: Codable, Equatable, Sendable {
    enum CodingKeys: String, CodingKey { case source = "quelle", width = "breite", height = "hoehe", exif }

    public var source: FotoQuelle
    public var width: Int?
    public var height: Int?

    public var exif: [String: String]

    public init(source: FotoQuelle, width: Int? = nil, height: Int? = nil, exif: [String: String] = [:]) {
        self.source = source
        self.width = width
        self.height = height
        self.exif = exif
    }

    public var aspekt: Double {
        guard let b = width, let h = height, h > 0 else { return 1 }
        return Double(b) / Double(h)
    }
}

public enum FotoFilter: Codable, Equatable, Sendable {
    case keiner
    case schwarzweiss
    case abgedunkelt(Double)

    public var isActive: Bool { self != .keiner }
}

public struct BildRechteck: Codable, Equatable, Sendable {
    public var ecke1: BildPunkt
    public var ecke2: BildPunkt
    public init(ecke1: BildPunkt, ecke2: BildPunkt) {
        self.ecke1 = ecke1
        self.ecke2 = ecke2
    }
    public var minX: Double { min(ecke1.x, ecke2.x) }
    public var minY: Double { min(ecke1.y, ecke2.y) }
    public var maxX: Double { max(ecke1.x, ecke2.x) }
    public var maxY: Double { max(ecke1.y, ecke2.y) }

    public var eckpunkte: [BildPunkt] {
        [BildPunkt(x: minX, y: minY), BildPunkt(x: maxX, y: minY),
         BildPunkt(x: maxX, y: maxY), BildPunkt(x: minX, y: maxY)]
    }
}

public enum SkizzenForm: Codable, Equatable, Sendable {
    case polylinie(points: [BildPunkt], geschlossen: Bool)
    case rechteck(BildRechteck)
    case freihand(points: [BildPunkt])

    public var points: [BildPunkt] {
        switch self {
        case let .polylinie(p, _): return p
        case let .rechteck(r):     return r.eckpunkte
        case let .freihand(p):     return p
        }
    }

    public var istGeschlossen: Bool {
        switch self {
        case let .polylinie(_, g): return g
        case .rechteck:            return true
        case .freihand:            return false
        }
    }
}

public enum SkizzenStrichFarbe: String, Codable, CaseIterable, Sendable {
    case schwarz, weiss, slot
    public var label: String {
        switch self {
        case .schwarz: return "Schwarz"
        case .weiss:   return "Weiß"
        case .slot:    return "Slot-Farbe"
        }
    }
}

public enum StrichDicke: String, Codable, CaseIterable, Sendable {
    case duenn, mittel, dick
    public var points: Double {
        switch self {
        case .duenn:  return 1.5
        case .mittel: return 3
        case .dick:   return 5
        }
    }
    public var label: String {
        switch self {
        case .duenn:  return "Dünn"
        case .mittel: return "Mittel"
        case .dick:   return "Dick"
        }
    }
}

public struct StrichStil: Codable, Equatable, Sendable {
    enum CodingKeys: String, CodingKey { case color = "farbe", dicke }

    public var color: SkizzenStrichFarbe
    public var dicke: StrichDicke
    public init(color: SkizzenStrichFarbe = .schwarz, dicke: StrichDicke = .mittel) {
        self.color = color
        self.dicke = dicke
    }
}

public struct SkizzenObjekt: Identifiable, Codable, Equatable, Sendable {
    enum CodingKeys: String, CodingKey { case id, form, strich, fuellSlotID, deckkraft, label = "bezeichnung" }

    public let id: UUID
    public var form: SkizzenForm
    public var strich: StrichStil

    public var fuellSlotID: UUID?
    public var deckkraft: Double
    public var label: String

    public init(id: UUID = UUID(), form: SkizzenForm, strich: StrichStil = StrichStil(),
                fuellSlotID: UUID? = nil, deckkraft: Double = 1, label: String = "") {
        self.id = id
        self.form = form
        self.strich = strich
        self.fuellSlotID = fuellSlotID
        self.deckkraft = deckkraft
        self.label = label
    }

    public var istGefuellt: Bool { fuellSlotID != nil && form.istGeschlossen }
}

public struct SkizzenDokument: Identifiable, Codable, Equatable, Sendable {
    enum CodingKeys: String, CodingKey { case id, projectNumber = "projektNummer", foto, photoFilter = "fotoFilter", layers, slots, massAnker, erstelltAm, geaendertAm }

    public let id: UUID
    public var projectNumber: String?
    public var foto: FotoReferenz
    public var photoFilter: FotoFilter
    public var layers: [SkizzenLayer]
    public var slots: [MaterialSlot]
    public var massAnker: [MassAnker]
    public var erstelltAm: Date
    public var geaendertAm: Date

    public init(id: UUID = UUID(), projectNumber: String? = nil, foto: FotoReferenz,
                photoFilter: FotoFilter = .keiner,
                layers: [SkizzenLayer] = SkizzenLayer.standardSatz(),
                slots: [MaterialSlot] = MaterialSlot.standardSatz(),
                massAnker: [MassAnker] = [],
                erstelltAm: Date = Date(), geaendertAm: Date = Date()) {
        self.id = id
        self.projectNumber = projectNumber
        self.foto = foto
        self.photoFilter = photoFilter
        self.layers = layers
        self.slots = slots
        self.massAnker = massAnker
        self.erstelltAm = erstelltAm
        self.geaendertAm = geaendertAm
    }

    public var alleObjekte: [SkizzenObjekt] { layers.flatMap(\.objekte) }

    public var exportLayers: [SkizzenLayer] {
        layers.filter { $0.isVisible && $0.art != .notiz }
    }

    public var exportObjekte: [SkizzenObjekt] { exportLayers.flatMap(\.objekte) }

    public var gemappteSlots: [MaterialSlot] { slots.filter { $0.zugeordnetesMaterial != nil } }

    public var benutzteSlotIDs: Set<UUID> {
        Set(exportObjekte.compactMap { $0.istGefuellt ? $0.fuellSlotID : nil })
    }

    public func substrateOpenPoints() -> [String] {
        var offen: [String] = []
        let gefuellt = exportObjekte.contains(where: \.istGefuellt)
        if !gefuellt { offen.append("Kein gefülltes Volumen") }
        let benutzt = benutzteSlotIDs
        let ohneMaterial = slots.filter { benutzt.contains($0.id) && $0.zugeordnetesMaterial == nil }
        if !ohneMaterial.isEmpty {
            offen.append("Slots ohne Material: " + ohneMaterial.map(\.label).joined(separator: ", "))
        }
        return offen
    }

    public var substratGruen: Bool { substrateOpenPoints().isEmpty }
}
