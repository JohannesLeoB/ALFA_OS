import Foundation

public struct MaterialAngabe: Codable, Equatable, Sendable {
    public var text: String

    public var paletteID: String?

    public var assetRef: String?

    public init(text: String = "", paletteID: String? = nil, assetRef: String? = nil) {
        self.text = text
        self.paletteID = paletteID
        self.assetRef = assetRef
    }

    public var isEmpty: Bool { text.trimmingCharacters(in: .whitespaces).isEmpty }
}

public struct MaterialDeklaration: Codable, Equatable, Sendable {
    public var front: MaterialAngabe
    public var korpus: MaterialAngabe
    public var sockel: MaterialAngabe
    public var schubkastenSystem: MaterialAngabe
    public var griff: MaterialAngabe
    public var arbeitsplatte: MaterialAngabe

    public init(front: MaterialAngabe = MaterialAngabe(),
                korpus: MaterialAngabe = MaterialAngabe(),
                sockel: MaterialAngabe = MaterialAngabe(text: "analog zu Front"),
                schubkastenSystem: MaterialAngabe = MaterialAngabe(),
                griff: MaterialAngabe = MaterialAngabe(),
                arbeitsplatte: MaterialAngabe = MaterialAngabe()) {
        self.front = front
        self.korpus = korpus
        self.sockel = sockel
        self.schubkastenSystem = schubkastenSystem
        self.griff = griff
        self.arbeitsplatte = arbeitsplatte
    }

    public var blattZeilen: [(label: String, angabe: MaterialAngabe)] {
        [("FRONT", front), ("KORPUS", korpus), ("SOCKEL", sockel),
         ("SCHUBKÄSTEN", schubkastenSystem), ("GRIFF", griff),
         ("ARBEITSPLATTE", arbeitsplatte)]
    }
}

public enum PaletteBereich: String, Codable, CaseIterable, Sendable {
    case front
    case korpus
    case sockel
    case schubkasten
    case griff
    case arbeitsplatte
}

public struct PaletteEintrag: Codable, Equatable, Sendable, Identifiable {
    enum CodingKeys: String, CodingKey { case id, area = "bereich", name, beschaffungshinweis, faktorSchluessel }

    public var id: String
    public var area: PaletteBereich
    public var name: String

    public var beschaffungshinweis: String?

    public var faktorSchluessel: String?

    public init(id: String, area: PaletteBereich, name: String,
                beschaffungshinweis: String? = nil, faktorSchluessel: String? = nil) {
        self.id = id
        self.area = area
        self.name = name
        self.beschaffungshinweis = beschaffungshinweis
        self.faktorSchluessel = faktorSchluessel
    }
}

public enum KonfigPalette {
    public static let seed: [PaletteEintrag] = [

        PaletteEintrag(id: "front.linoleum.forbo", area: .front,
                       name: "Linoleum (Forbo Desktop, beidseitig)",
                       beschaffungshinweis: "Forbo-Farbnummer angeben, beidseitig auf Trägerplatte",
                       faktorSchluessel: "linoleum"),
        PaletteEintrag(id: "front.furnier.nussbaum", area: .front,
                       name: "Nussbaum-Furnierspan, klar matt lackiert",
                       beschaffungshinweis: "Furnierspan 19 mm, Furnierkante 1 mm, nach Bemusterung",
                       faktorSchluessel: "furnier"),
        PaletteEintrag(id: "front.furnier.eiche", area: .front,
                       name: "Eiche-Furnierspan, klar matt lackiert",
                       beschaffungshinweis: "Furnierspan, Furnierkante, nach Bemusterung",
                       faktorSchluessel: "furnier"),
        PaletteEintrag(id: "front.lack", area: .front,
                       name: "MDF lackiert (NCS/RAL nach Bemusterung)",
                       beschaffungshinweis: "Farbton nach Bemusterung",
                       faktorSchluessel: "lack"),
        PaletteEintrag(id: "front.valchromat", area: .front,
                       name: "Valchromat durchgefärbt",
                       beschaffungshinweis: "durchgefärbtes MDF, geölt",
                       faktorSchluessel: "valchromat"),
        PaletteEintrag(id: "front.edelstahl", area: .front,
                       name: "Edelstahl",
                       beschaffungshinweis: "Blech auf Trägerplatte, Schliffbild abstimmen",
                       faktorSchluessel: "edelstahl"),
        PaletteEintrag(id: "front.massivholz", area: .front,
                       name: "Massivholz",
                       beschaffungshinweis: "Holzart + Oberfläche nach Bemusterung",
                       faktorSchluessel: "massivholz"),

        PaletteEintrag(id: "korpus.egger.weiss", area: .korpus,
                       name: "Dekorspan Egger ST9, weiß",
                       beschaffungshinweis: "Egger Lagerprogramm"),
        PaletteEintrag(id: "korpus.egger.hellgrau", area: .korpus,
                       name: "Dekorspan Egger ST9, hellgrau",
                       beschaffungshinweis: "Egger Lagerprogramm"),

        PaletteEintrag(id: "sockel.front", area: .sockel, name: "analog zu Front"),
        PaletteEintrag(id: "sockel.schwarz", area: .sockel, name: "schwarz, zurückgesetzt"),

        PaletteEintrag(id: "schub.legrabox.carbon", area: .schubkasten,
                       name: "Blum Legrabox, Carbonschwarz",
                       faktorSchluessel: "legrabox"),
        PaletteEintrag(id: "schub.holz.massiv", area: .schubkasten,
                       name: "Holz massiv, gezinkt (Eiche/Nussbaum)",
                       beschaffungshinweis: "Holzart analog Front abstimmen",
                       faktorSchluessel: "massivholz"),

        PaletteEintrag(id: "griff.pto", area: .griff,
                       name: "grifflos, Push-to-Open",
                       beschaffungshinweis: "PTO-Mechanik; Kühlschrank mit eingelassenen Griffmulden"),
        PaletteEintrag(id: "griff.mulde", area: .griff,
                       name: "eingelassene Griffmulde"),
        PaletteEintrag(id: "griff.buegel", area: .griff,
                       name: "Bügelgriff (nach Bemusterung)"),

        PaletteEintrag(id: "apl.naturstein", area: .arbeitsplatte,
                       name: "Naturstein (z. B. Nero Marquina), 20 mm",
                       beschaffungshinweis: "Oberfläche geschliffen, Kanten gefast und geschliffen — Steinmetz",
                       faktorSchluessel: "naturstein"),
        PaletteEintrag(id: "apl.keramik", area: .arbeitsplatte,
                       name: "Keramik",
                       beschaffungshinweis: "Steinmetz/Verarbeiter",
                       faktorSchluessel: "keramik"),
        PaletteEintrag(id: "apl.edelstahl", area: .arbeitsplatte,
                       name: "Edelstahl (Stadler)",
                       beschaffungshinweis: "Edelstahl-AP über Stadler",
                       faktorSchluessel: "edelstahl"),
        PaletteEintrag(id: "apl.massivholz", area: .arbeitsplatte,
                       name: "Massivholz (Tischler)",
                       beschaffungshinweis: "vom Tischler, Holzart analog Front",
                       faktorSchluessel: "massivholz"),
        PaletteEintrag(id: "apl.linoleum", area: .arbeitsplatte,
                       name: "Linoleum auf Träger (Tischler)",
                       faktorSchluessel: "linoleum")
    ]

    public static func entries(area: PaletteBereich) -> [PaletteEintrag] {
        seed.filter { $0.area == area }
    }

    public static func entry(id: String) -> PaletteEintrag? {
        seed.first { $0.id == id }
    }

    public static func alsMaterialReferenzen() -> [MaterialRef] {
        seed.map { entry in
            MaterialRef(
                id: Self.stabileUUID(fuer: entry.id),
                displayName: entry.name,
                promptText: entry.name,
                art: .material)
        }
    }

    static func stabileUUID(fuer text: String) -> UUID {
        func fnv1a(_ s: String) -> UInt64 {
            var hash: UInt64 = 0xcbf29ce484222325
            for byte in s.utf8 {
                hash ^= UInt64(byte)
                hash = hash &* 0x100000001B3
            }
            return hash
        }
        let a = fnv1a(text).bigEndian
        let b = fnv1a(text + "#").bigEndian
        var bytes = [UInt8]()
        withUnsafeBytes(of: a) { bytes.append(contentsOf: $0) }
        withUnsafeBytes(of: b) { bytes.append(contentsOf: $0) }
        return bytes.withUnsafeBufferPointer { NSUUID(uuidBytes: $0.baseAddress!) as UUID }
    }

    public static func schaetzText(fuer angabe: MaterialAngabe) -> String {
        var teile = [angabe.text]
        if let id = angabe.paletteID, let entry = entry(id: id) {
            teile.append(entry.name)
            if let key = entry.faktorSchluessel { teile.append(key) }
        }
        return teile.filter { !$0.isEmpty }.joined(separator: " ")
    }
}
