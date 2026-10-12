import Foundation

public struct Gericht: Equatable, Sendable, Identifiable {
    public let id: String
    public let date: Date
    public let name: String
    public let kategorieID: Int?
    public let mitarbeiterpreis: Decimal?
    public let gaestepreis: Decimal?

    public let imageUrl: URL?

    public let allergeneIDs: Set<Int>
    public let zusatzstoffeIDs: Set<Int>
    public let merkmaleIDs: Set<Int>
    public let naehrwerte: Naehrwerte?

    public init(id: String, date: Date, name: String, kategorieID: Int? = nil,
                mitarbeiterpreis: Decimal? = nil, gaestepreis: Decimal? = nil,
                imageUrl: URL? = nil, allergeneIDs: Set<Int> = [], zusatzstoffeIDs: Set<Int> = [],
                merkmaleIDs: Set<Int> = [], naehrwerte: Naehrwerte? = nil) {
        self.id = id; self.date = date; self.name = name; self.kategorieID = kategorieID
        self.mitarbeiterpreis = mitarbeiterpreis; self.gaestepreis = gaestepreis
        self.imageUrl = imageUrl; self.allergeneIDs = allergeneIDs
        self.zusatzstoffeIDs = zusatzstoffeIDs; self.merkmaleIDs = merkmaleIDs
        self.naehrwerte = naehrwerte
    }
}

public struct Naehrwerte: Equatable, Sendable {
    public let kcal: Int?
    public let fett: Double?
    public let kohlenhydrate: Double?
    public let eiweiss: Double?

    public init(kcal: Int? = nil, fett: Double? = nil,
                kohlenhydrate: Double? = nil, eiweiss: Double? = nil) {
        self.kcal = kcal; self.fett = fett
        self.kohlenhydrate = kohlenhydrate; self.eiweiss = eiweiss
    }
}

public struct SpeisePraeferenzen: Equatable, Sendable, Codable {
    public var ausgeschlosseneAllergene: Set<Int>
    public var ausgeschlosseneZusatzstoffe: Set<Int>

    public init(ausgeschlosseneAllergene: Set<Int> = [], ausgeschlosseneZusatzstoffe: Set<Int> = []) {
        self.ausgeschlosseneAllergene = ausgeschlosseneAllergene
        self.ausgeschlosseneZusatzstoffe = ausgeschlosseneZusatzstoffe
    }

    public var isEmpty: Bool {
        ausgeschlosseneAllergene.isEmpty && ausgeschlosseneZusatzstoffe.isEmpty
    }
}

public enum SpeiseplanHeute: Equatable, Sendable {
    case gerichte([Gericht])

    case keinPlanHeute

    case allesGefiltert(total: Int)

    public var klartext: String? {
        switch self {
        case .gerichte: nil
        case .keinPlanHeute: "Heute kein Speiseplan — Feiertag oder Betriebsruhe."
        case .allesGefiltert(let total):
            "Alle \(total) Gerichte enthalten etwas von deiner Ausschlussliste."
        }
    }
}

public enum SpeiseplanFilter {
    public static func heute(
        alle: [Gericht], praeferenzen: SpeisePraeferenzen, heute: Date, kalender: Calendar = .current
    ) -> SpeiseplanHeute {
        let vonHeute = alle.filter { kalender.isDate($0.date, inSameDayAs: heute) }
        guard vonHeute.isEmpty == false else { return .keinPlanHeute }
        let erlaubt = vonHeute.filter { istErlaubt($0, praeferenzen: praeferenzen) }
        guard erlaubt.isEmpty == false else { return .allesGefiltert(total: vonHeute.count) }
        return .gerichte(erlaubt)
    }

    public static func istErlaubt(_ gericht: Gericht, praeferenzen: SpeisePraeferenzen) -> Bool {
        gericht.allergeneIDs.isDisjoint(with: praeferenzen.ausgeschlosseneAllergene)
            && gericht.zusatzstoffeIDs.isDisjoint(with: praeferenzen.ausgeschlosseneZusatzstoffe)
    }

    public static func parseIDs(_ roh: String?) -> Set<Int> {
        guard let roh, roh.isEmpty == false else { return [] }
        return Set(roh.split(separator: ",").compactMap {
            Int($0.trimmingCharacters(in: .whitespaces))
        })
    }
}

public struct SpeisePraeferenzenSpeicher: Sendable {
    public static let key = "happahappa.praeferenzen"

    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func load() -> SpeisePraeferenzen {
        guard let data = defaults.data(forKey: Self.key),
              let p = try? JSONDecoder().decode(SpeisePraeferenzen.self, from: data)
        else { return .init() }
        return p
    }

    public func save(_ praeferenzen: SpeisePraeferenzen) throws {
        defaults.set(try JSONEncoder().encode(praeferenzen), forKey: Self.key)
    }
}
