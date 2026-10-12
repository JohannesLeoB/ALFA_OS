import Foundation

public enum NachfassQuelle: String, Codable, CaseIterable, Sendable, Identifiable {
    case lead
    case angebot
    case slackImport
    case manuell

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .lead:        return "Lead"
        case .angebot:     return "Angebot"
        case .slackImport: return "Anfrage"
        case .manuell:     return "Manuell"
        }
    }
}

public enum NachfassKanal: String, Codable, CaseIterable, Sendable, Identifiable {
    case mail
    case telefon
    case appointment
    case slack

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .mail:    return "Mail"
        case .telefon: return "Telefon"
        case .appointment:  return "Termin"
        case .slack:   return "Slack"
        }
    }
}

public enum NachfassStatus: String, Codable, CaseIterable, Sendable, Identifiable {
    case offen
    case nachgefasst
    case gewonnen
    case verloren
    case pausiert

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .offen:       return "Offen"
        case .nachgefasst: return "Nachgefasst"
        case .gewonnen:    return "Gewonnen"
        case .verloren:    return "Verloren"
        case .pausiert:    return "Pausiert"
        }
    }

    public var isActive: Bool { self == .offen || self == .nachgefasst }

    public var istEntschieden: Bool { self == .gewonnen || self == .verloren }
}

public enum NachfassVerlustgrund: String, Codable, CaseIterable, Sendable, Identifiable {
    case zuTeuer
    case wettbewerber
    case projektGestorben
    case keineReaktion
    case selbstGeloest
    case sonstiges

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .zuTeuer:         return "Zu teuer"
        case .wettbewerber:    return "An Wettbewerber"
        case .projektGestorben: return "Projekt gestorben"
        case .keineReaktion:   return "Keine Reaktion"
        case .selbstGeloest:   return "Selbst gelöst"
        case .sonstiges:       return "Sonstiges"
        }
    }
}

public struct NachfassKontakt: Codable, Equatable, Sendable {
    enum CodingKeys: String, CodingKey { case date = "datum", kanal }

    public var date: Date
    public var kanal: NachfassKanal
    public init(date: Date, kanal: NachfassKanal) {
        self.date = date
        self.kanal = kanal
    }
}

public struct NachfassFall: Codable, Equatable, Sendable, Identifiable {
    enum CodingKeys: String, CodingKey { case id, source = "quelle", customerName = "kundeName", customerNumber = "kundennummer", projektID, leadID, value = "wert", angebotsNummer, angebotsDatum, letzterKontakt, naechstesNachfassen, versuche, status, verlustGrund, verlustGrundText, notizen, erstelltAm, aktualisiertAm }

    public let id: String
    public var source: NachfassQuelle
    public var customerName: String
    public var customerNumber: String?
    public var projektID: String?
    public var leadID: String?
    public var value: Double?
    public var angebotsNummer: String?
    public var angebotsDatum: Date?
    public var letzterKontakt: NachfassKontakt?
    public var naechstesNachfassen: Date?
    public var versuche: Int
    public var status: NachfassStatus
    public var verlustGrund: NachfassVerlustgrund?
    public var verlustGrundText: String?
    public var notizen: String?
    public var erstelltAm: Date
    public var aktualisiertAm: Date

    public init(
        id: String = UUID().uuidString,
        source: NachfassQuelle,
        customerName: String,
        customerNumber: String? = nil,
        projektID: String? = nil,
        leadID: String? = nil,
        value: Double? = nil,
        angebotsNummer: String? = nil,
        angebotsDatum: Date? = nil,
        letzterKontakt: NachfassKontakt? = nil,
        naechstesNachfassen: Date? = nil,
        versuche: Int = 0,
        status: NachfassStatus = .offen,
        verlustGrund: NachfassVerlustgrund? = nil,
        verlustGrundText: String? = nil,
        notizen: String? = nil,
        erstelltAm: Date = Date(),
        aktualisiertAm: Date = Date()
    ) {
        self.id = id
        self.source = source
        self.customerName = customerName
        self.customerNumber = customerNumber
        self.projektID = projektID
        self.leadID = leadID
        self.value = value
        self.angebotsNummer = angebotsNummer
        self.angebotsDatum = angebotsDatum
        self.letzterKontakt = letzterKontakt
        self.naechstesNachfassen = naechstesNachfassen
        self.versuche = versuche
        self.status = status
        self.verlustGrund = verlustGrund
        self.verlustGrundText = verlustGrundText
        self.notizen = notizen
        self.erstelltAm = erstelltAm
        self.aktualisiertAm = aktualisiertAm
    }

    public var stilleBezug: Date { letzterKontakt?.date ?? angebotsDatum ?? erstelltAm }
}

public enum NachfassAuswertung {
    public static let standardKadenzTage = 7

    public static func naechsterTermin(basis: Date, kadenzTage: Int = standardKadenzTage) -> Date {
        Calendar.current.date(byAdding: .day, value: kadenzTage, to: basis) ?? basis
    }

    public static func tageStill(_ fall: NachfassFall, heute: Date = Date()) -> Int {
        let k = Calendar.current
        let tage = k.dateComponents([.day], from: k.startOfDay(for: fall.stilleBezug),
                                    to: k.startOfDay(for: heute)).day ?? 0
        return max(0, tage)
    }

    public static func faellig(_ faelle: [NachfassFall], heute: Date = Date()) -> [NachfassFall] {
        let k = Calendar.current
        return faelle.filter { fall in
            guard fall.status.isActive, let appointment = fall.naechstesNachfassen else { return false }
            return k.startOfDay(for: appointment) <= k.startOfDay(for: heute)
        }
    }

    public static func dringlichkeit(_ fall: NachfassFall, heute: Date = Date()) -> Double {
        let still = Double(tageStill(fall, heute: heute))
        let frische = max(0.05, 1.0 - still / 120.0)
        return (fall.value ?? 0) * frische
    }

    public static func sortiertNachDringlichkeit(_ faelle: [NachfassFall], heute: Date = Date()) -> [NachfassFall] {
        faelle.sorted { a, b in
            let da = dringlichkeit(a, heute: heute), db = dringlichkeit(b, heute: heute)
            if da != db { return da > db }
            return tageStill(a, heute: heute) < tageStill(b, heute: heute)
        }
    }

    public static func aktiveAnzahl(_ faelle: [NachfassFall]) -> Int {
        faelle.filter { $0.status.isActive }.count
    }

    public static func gewichtetePipeline(_ faelle: [NachfassFall]) -> Double {
        faelle.filter { $0.status.isActive }.compactMap { $0.value }.reduce(0, +)
    }

    public static func conversion(_ faelle: [NachfassFall], tage: Int, heute: Date = Date()) -> Double? {
        let k = Calendar.current
        guard let grenze = k.date(byAdding: .day, value: -tage, to: heute) else { return nil }
        let entschieden = faelle.filter { $0.status.istEntschieden && $0.aktualisiertAm >= grenze }
        guard entschieden.isEmpty == false else { return nil }
        let gewonnen = entschieden.filter { $0.status == .gewonnen }.count
        return Double(gewonnen) / Double(entschieden.count)
    }
}
