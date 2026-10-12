import Foundation

public enum KonfigStatus: String, Codable, CaseIterable, Sendable {
    case vorplanung
    case vorabzug
    case finalisiert

    public var stempelText: String? {
        switch self {
        case .vorplanung: return "VORPLANUNG"
        case .vorabzug: return "VORABZUG"
        case .finalisiert: return nil
        }
    }

    public var displayName: String {
        switch self {
        case .vorplanung: return "Vorplanung"
        case .vorabzug: return "Vorabzug"
        case .finalisiert: return "Final"
        }
    }
}

public enum RaumBezug: Codable, Equatable, Sendable {
    case aufmass(entwurfID: String)

    case skizze(entwurfID: String)

    case foto(pfad: String)

    case freieMasse(widthMm: Int, tiefeMM: Int, heightMm: Int)

    case keiner
}

public struct RaumPosition: Codable, Equatable, Sendable {
    public var xMM: Int
    public var yMM: Int

    public var rotationGrad: Int

    public init(xMM: Int, yMM: Int, rotationGrad: Int = 0) {
        self.xMM = xMM
        self.yMM = yMM
        self.rotationGrad = rotationGrad
    }
}

public enum GeraetKategorie: String, Codable, CaseIterable, Sendable {
    case backofen
    case kochfeld
    case dunstabzug
    case geschirrspueler
    case kuehlGefrier
    case mikrowelle
    case waermeschublade
    case kaffeevollautomat
    case weinschrank
    case sonstiges

    public var displayName: String {
        switch self {
        case .backofen: return "Backofen"
        case .kochfeld: return "Kochfeld"
        case .dunstabzug: return "Dunstabzug"
        case .geschirrspueler: return "Geschirrspüler"
        case .kuehlGefrier: return "Kühl-/Gefrierschrank"
        case .mikrowelle: return "Mikrowelle"
        case .waermeschublade: return "Wärmeschublade"
        case .kaffeevollautomat: return "Kaffeevollautomat"
        case .weinschrank: return "Weinschrank"
        case .sonstiges: return "Gerät"
        }
    }

    public var blattLabel: String {
        switch self {
        case .backofen: return "BACKOFEN"
        case .kochfeld: return "KOCHFELD"
        case .dunstabzug: return "DUNSTABZUG"
        case .geschirrspueler: return "GESCHIRRSPÜLER"
        case .kuehlGefrier: return "EINBAU-KÜHLSCHRANK"
        case .mikrowelle: return "MIKROWELLE"
        case .waermeschublade: return "WÄRMESCHUBLADE"
        case .kaffeevollautomat: return "KAFFEEMASCHINE"
        case .weinschrank: return "WEINSCHRANK"
        case .sonstiges: return "GERÄT"
        }
    }
}

public struct ArtikelRef: Codable, Equatable, Sendable {
    enum CodingKeys: String, CodingKey { case artikelID, displayName = "anzeigeName", imageUrl = "bildURL", standAm }

    public var artikelID: String
    public var displayName: String
    public var imageUrl: String?
    public var standAm: Date

    public init(artikelID: String, displayName: String, imageUrl: String? = nil, standAm: Date) {
        self.artikelID = artikelID
        self.displayName = displayName
        self.imageUrl = imageUrl
        self.standAm = standAm
    }
}

public struct GeraetSlot: Codable, Equatable, Sendable {
    public var kategorie: GeraetKategorie
    public var artikel: ArtikelRef?

    public var nischeBreiteMM: Int?
    public var nischeHoeheMM: Int?

    public init(kategorie: GeraetKategorie, artikel: ArtikelRef? = nil,
                nischeBreiteMM: Int? = nil, nischeHoeheMM: Int? = nil) {
        self.kategorie = kategorie
        self.artikel = artikel
        self.nischeBreiteMM = nischeBreiteMM
        self.nischeHoeheMM = nischeHoeheMM
    }
}

public enum SchubMaterial: String, Codable, CaseIterable, Sendable {
    case legrabox
    case holzMassiv

    public var displayName: String {
        switch self {
        case .legrabox: return "Legrabox"
        case .holzMassiv: return "Holz massiv"
        }
    }
}

public enum Ausstattung: Codable, Equatable, Sendable {
    case tuerMitFachboeden

    case schubkaesten(count: Int, material: SchubMaterial)

    case offenesRegal

    case fachboeden

    case blende

    case geraet(GeraetSlot)

    case spuelbecken

    case muellAuszug

    case isEmpty

    public var blattLabel: String {
        switch self {
        case .tuerMitFachboeden: return "FACHBÖDEN"
        case .schubkaesten: return "SCHUBKASTEN"
        case .offenesRegal: return "OFFENES REGAL"
        case .fachboeden: return "FACHBÖDEN"
        case .blende: return "BLENDE"
        case .geraet(let slot): return slot.kategorie.blattLabel
        case .spuelbecken: return "SPÜLBECKEN"
        case .muellAuszug: return "MÜLL-AUSZUG"
        case .isEmpty: return "LEER"
        }
    }

    public var schubAnzahl: Int {
        if case .schubkaesten(let count, _) = self { return max(0, count) }
        return 0
    }

    public var zaehltAlsKorpus: Bool {
        switch self {
        case .blende, .isEmpty: return false
        default: return true
        }
    }
}

public struct KonfigFach: Codable, Equatable, Sendable, Identifiable {
    enum CodingKeys: String, CodingKey { case id, heightMm = "hoeheMM", ausstattung }

    public var id: UUID

    public var heightMm: Int?
    public var ausstattung: Ausstattung

    public init(id: UUID = UUID(), heightMm: Int? = nil, ausstattung: Ausstattung) {
        self.id = id
        self.heightMm = heightMm
        self.ausstattung = ausstattung
    }
}

public struct KonfigSegment: Codable, Equatable, Sendable, Identifiable {
    enum CodingKeys: String, CodingKey { case id, widthMm = "breiteMM", faecher }

    public var id: UUID
    public var widthMm: Int

    public var faecher: [KonfigFach]

    public init(id: UUID = UUID(), widthMm: Int, faecher: [KonfigFach]) {
        self.id = id
        self.widthMm = widthMm
        self.faecher = faecher
    }

    public init(id: UUID = UUID(), widthMm: Int, ausstattung: Ausstattung) {
        self.init(id: id, widthMm: widthMm, faecher: [KonfigFach(ausstattung: ausstattung)])
    }

    public static let breitenRaster: [Int] = [300, 400, 450, 600, 800, 1200]

    public var alleAusstattungen: [Ausstattung] { faecher.map(\.ausstattung) }

    public var schubkaestenGesamt: Int { faecher.reduce(0) { $0 + $1.ausstattung.schubAnzahl } }
}

public enum ZonenTyp: Codable, Equatable, Sendable {
    case rowItem

    case wandzeile

    case hochschrankwand

    case insel

    case frei(String)

    public var displayName: String {
        switch self {
        case .rowItem: return "Zeile"
        case .wandzeile: return "Wandschränke"
        case .hochschrankwand: return "Hochschränke"
        case .insel: return "Insel"
        case .frei(let name): return name
        }
    }

    public var hatArbeitsplatte: Bool {
        switch self {
        case .rowItem, .insel: return true
        case .wandzeile, .hochschrankwand: return false
        case .frei: return false
        }
    }
}

public struct KonfigZone: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var typ: ZonenTyp

    public var name: String
    public var tiefeMM: Int

    public var korpusHoeheMM: Int
    public var sockelMM: Int

    public var hoehenbaenderMM: [Int]
    public var segmente: [KonfigSegment]

    public var position: RaumPosition?

    public var ueberstandMM: Int

    public init(id: UUID = UUID(), typ: ZonenTyp, name: String = "",
                tiefeMM: Int = 600, korpusHoeheMM: Int = 780, sockelMM: Int = 80,
                hoehenbaenderMM: [Int] = [], segmente: [KonfigSegment] = [],
                position: RaumPosition? = nil, ueberstandMM: Int = 0) {
        self.id = id
        self.typ = typ
        self.name = name
        self.tiefeMM = tiefeMM
        self.korpusHoeheMM = korpusHoeheMM
        self.sockelMM = sockelMM
        self.hoehenbaenderMM = hoehenbaenderMM
        self.segmente = segmente
        self.position = position
        self.ueberstandMM = ueberstandMM
    }

    public var displayName: String { name.isEmpty ? typ.displayName : name }

    public var breiteGesamtMM: Int { segmente.reduce(0) { $0 + $1.widthMm } }

    public var korpusAnzahl: Int {
        segmente.reduce(0) { sum, segment in
            sum + segment.faecher.filter { $0.ausstattung.zaehltAlsKorpus }.count
        }
    }

    public var schubkaestenGesamt: Int { segmente.reduce(0) { $0 + $1.schubkaestenGesamt } }

    public var geraeteSlots: [GeraetSlot] {
        segmente.flatMap { $0.faecher.compactMap { fach in
            if case .geraet(let slot) = fach.ausstattung { return slot }
            return nil
        } }
    }
}

public struct QuellenStand: Codable, Equatable, Sendable {
    public var kompiliertAm: Date
    public var aufmassStand: Date?
    public var artikelPreiseStand: Date?
    public var moodboardStand: Date?

    public var schaetzmodellNotiz: String?

    public init(kompiliertAm: Date, aufmassStand: Date? = nil,
                artikelPreiseStand: Date? = nil, moodboardStand: Date? = nil,
                schaetzmodellNotiz: String? = nil) {
        self.kompiliertAm = kompiliertAm
        self.aufmassStand = aufmassStand
        self.artikelPreiseStand = artikelPreiseStand
        self.moodboardStand = moodboardStand
        self.schaetzmodellNotiz = schaetzmodellNotiz
    }
}

public struct KompilatEintrag: Codable, Equatable, Sendable {
    enum CodingKeys: String, CodingKey { case id, art, state = "stand", fileName = "dateiName" }

    public enum Art: String, Codable, Sendable {
        case anfrageTischler
        case anfrageStein
        case kundenSet
    }

    public var id: UUID
    public var art: Art
    public var state: QuellenStand
    public var fileName: String

    public init(id: UUID = UUID(), art: Art, state: QuellenStand, fileName: String) {
        self.id = id
        self.art = art
        self.state = state
        self.fileName = fileName
    }
}

public struct KonfigEntwurf: Codable, Equatable, Sendable, Identifiable {
    enum CodingKeys: String, CodingKey { case id, projectNumber = "projektNummer", variantenName, status, raumBezug, material, zonen, notizen, erstelltAm, geaendertAm, zeitfenster, kompilate }

    public var id: UUID

    public var projectNumber: String

    public var variantenName: String
    public var status: KonfigStatus
    public var raumBezug: RaumBezug
    public var material: MaterialDeklaration
    public var zonen: [KonfigZone]
    public var notizen: String
    public var erstelltAm: Date
    public var geaendertAm: Date

    public var zeitfenster: String
    public var kompilate: [KompilatEintrag]

    public init(id: UUID = UUID(), projectNumber: String,
                variantenName: String = "Entwurf A",
                status: KonfigStatus = .vorplanung,
                raumBezug: RaumBezug = .keiner,
                material: MaterialDeklaration = MaterialDeklaration(),
                zonen: [KonfigZone] = [],
                notizen: String = "",
                erstelltAm: Date = Date(), geaendertAm: Date = Date(),
                zeitfenster: String = "",
                kompilate: [KompilatEintrag] = []) {
        self.id = id
        self.projectNumber = projectNumber
        self.variantenName = variantenName
        self.status = status
        self.raumBezug = raumBezug
        self.material = material
        self.zonen = zonen
        self.notizen = notizen
        self.erstelltAm = erstelltAm
        self.geaendertAm = geaendertAm
        self.zeitfenster = zeitfenster
        self.kompilate = kompilate
    }

    public var korpusAnzahl: Int { zonen.reduce(0) { $0 + $1.korpusAnzahl } }
    public var schubkaestenGesamt: Int { zonen.reduce(0) { $0 + $1.schubkaestenGesamt } }
    public var geraeteSlots: [GeraetSlot] { zonen.flatMap(\.geraeteSlots) }

    public func dupliziert(alsVariante neuerName: String, am date: Date = Date()) -> KonfigEntwurf {
        var kopie = self
        kopie.id = UUID()
        kopie.variantenName = neuerName
        kopie.erstelltAm = date
        kopie.geaendertAm = date
        kopie.kompilate = []
        kopie.zonen = zonen.map { zone in
            var z = zone
            z.id = UUID()
            z.segmente = zone.segmente.map { segment in
                var s = segment
                s.id = UUID()
                s.faecher = segment.faecher.map { fach in
                    var f = fach
                    f.id = UUID()
                    return f
                }
                return s
            }
            return z
        }
        return kopie
    }

    public static func naechsterVariantenName(vorhandene: [String]) -> String {
        let buchstaben = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".map(String.init)
        for b in buchstaben {
            let kandidat = "Entwurf \(b)"
            if !vorhandene.contains(kandidat) { return kandidat }
        }
        return "Entwurf \(vorhandene.count + 1)"
    }
}

public enum Gewerk: String, Codable, CaseIterable, Sendable {
    case tischler
    case steinmetz
    case mykilos

    public var displayName: String {
        switch self {
        case .tischler: return "Tischler"
        case .steinmetz: return "Steinmetz"
        case .mykilos: return "MYKILOS"
        }
    }
}

public enum GewerkScope {
    public static func arbeitsplatteIstScope(von trade: Gewerk) -> Bool {
        trade == .steinmetz
    }

    public static func geraeteSindScope(von trade: Gewerk) -> Bool {
        trade == .mykilos
    }

    public static func korpenSindScope(von trade: Gewerk) -> Bool {
        trade == .tischler
    }
}
