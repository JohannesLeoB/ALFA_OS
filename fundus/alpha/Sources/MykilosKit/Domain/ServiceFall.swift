import Foundation

public enum ServiceArt: String, Codable, CaseIterable, Sendable, Identifiable {
    case reklamation
    case nachbesserung
    case service
    case wartung

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .reklamation:   return "Reklamation"
        case .nachbesserung: return "Nachbesserung"
        case .service:       return "Service"
        case .wartung:       return "Wartung"
        }
    }
}

public enum ServiceStatus: String, Codable, CaseIterable, Sendable, Identifiable {
    case offen
    case inBearbeitung
    case wartetKunde
    case erledigt
    case abgelehnt

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .offen:         return "Offen"
        case .inBearbeitung: return "In Bearbeitung"
        case .wartetKunde:   return "Wartet auf Kunde"
        case .erledigt:      return "Erledigt"
        case .abgelehnt:     return "Abgelehnt"
        }
    }

    public var sortRang: Int {
        switch self {
        case .offen:         return 0
        case .inBearbeitung: return 1
        case .wartetKunde:   return 2
        case .erledigt:      return 3
        case .abgelehnt:     return 4
        }
    }
    public var istAbgeschlossen: Bool { self == .erledigt || self == .abgelehnt }
}

public struct ServiceFall: Codable, Equatable, Sendable, Identifiable {
    enum CodingKeys: String, CodingKey { case id, projectNumber = "projektNummer", title = "titel", beschreibung, art, status, gemeldetAm, faelligAm, melder, erstelltAm, aktualisiertAm }

    public let id: String
    public let projectNumber: String
    public var title: String
    public var beschreibung: String?
    public var art: ServiceArt
    public var status: ServiceStatus
    public var gemeldetAm: Date
    public var faelligAm: Date?
    public var melder: String?
    public var erstelltAm: Date
    public var aktualisiertAm: Date

    public init(
        id: String = UUID().uuidString,
        projectNumber: String,
        title: String,
        beschreibung: String? = nil,
        art: ServiceArt = .reklamation,
        status: ServiceStatus = .offen,
        gemeldetAm: Date = Date(),
        faelligAm: Date? = nil,
        melder: String? = nil,
        erstelltAm: Date = Date(),
        aktualisiertAm: Date = Date()
    ) {
        self.id = id
        self.projectNumber = projectNumber
        self.title = title
        self.beschreibung = beschreibung
        self.art = art
        self.status = status
        self.gemeldetAm = gemeldetAm
        self.faelligAm = faelligAm
        self.melder = melder
        self.erstelltAm = erstelltAm
        self.aktualisiertAm = aktualisiertAm
    }
}

public enum ServiceAuswertung {
    public static func sortiert(_ faelle: [ServiceFall]) -> [ServiceFall] {
        faelle.sorted { a, b in
            if a.status.sortRang != b.status.sortRang { return a.status.sortRang < b.status.sortRang }
            return a.gemeldetAm > b.gemeldetAm
        }
    }

    public static func offeneAnzahl(_ faelle: [ServiceFall]) -> Int {
        faelle.filter { !$0.status.istAbgeschlossen }.count
    }

    public static func ueberfaellig(_ faelle: [ServiceFall], jetzt: Date = Date()) -> [ServiceFall] {
        faelle.filter { fall in
            guard !fall.status.istAbgeschlossen, let f = fall.faelligAm else { return false }
            return f < jetzt
        }
    }
}
