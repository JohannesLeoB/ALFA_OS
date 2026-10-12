import Foundation

public enum BestellStatus: String, Codable, CaseIterable, Sendable {
    case offen
    case bestellt
    case abErhalten
    case geliefert

    public var label: String {
        switch self {
        case .offen: "Offen"
        case .bestellt: "Bestellt"
        case .abErhalten: "AB erhalten"
        case .geliefert: "Geliefert"
        }
    }
}

public enum BestellWeg: String, Codable, CaseIterable, Sendable {
    case mail, telefon, portal, haendler, sonstig

    public var label: String {
        switch self {
        case .mail: "per Mail"
        case .telefon: "telefonisch"
        case .portal: "Portal/Shop"
        case .haendler: "über Händler"
        case .sonstig: "sonstig"
        }
    }
}

public struct BestellPosition: Codable, Equatable, Sendable, Identifiable {
    enum CodingKeys: String, CodingKey { case id, objektID, articleNumber = "artikelnummer", label = "bezeichnung", quantity = "menge", notiz }

    public let id: String

    public let objektID: String
    public let articleNumber: String
    public let label: String
    public let quantity: Int
    public let notiz: String?

    public init(id: String = UUID().uuidString, objektID: String = "",
                articleNumber: String = "", label: String, quantity: Int,
                notiz: String? = nil) {
        self.id = id
        self.objektID = objektID
        self.articleNumber = articleNumber
        self.label = label
        self.quantity = quantity
        self.notiz = notiz
    }
}

public struct Order: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let projectNumber: String
    public var lieferant: String
    public var weg: BestellWeg

    public var lieferort: String
    public var status: BestellStatus
    public var bestelltAm: Date?
    public var bestelltDurch: String?

    public var fromNumber: String?

    public var liefertermin: Date?
    public var lieferterminText: String?
    public var notiz: String?
    public var positionen: [BestellPosition]
    public var angelegtAm: Date

    public init(id: String = UUID().uuidString, projectNumber: String, lieferant: String,
                weg: BestellWeg = .mail, lieferort: String = "", status: BestellStatus = .offen,
                bestelltAm: Date? = nil, bestelltDurch: String? = nil, fromNumber: String? = nil,
                liefertermin: Date? = nil, lieferterminText: String? = nil, notiz: String? = nil,
                positionen: [BestellPosition] = [], angelegtAm: Date = Date()) {
        self.id = id
        self.projectNumber = projectNumber
        self.lieferant = lieferant
        self.weg = weg
        self.lieferort = lieferort
        self.status = status
        self.bestelltAm = bestelltAm
        self.bestelltDurch = bestelltDurch
        self.fromNumber = fromNumber
        self.liefertermin = liefertermin
        self.lieferterminText = lieferterminText
        self.notiz = notiz
        self.positionen = positionen
        self.angelegtAm = angelegtAm
    }
}

public struct BestellKorbPosition: Equatable, Sendable {
    public let objektID: String
    public let label: String
    public let quantity: Int

    public init(objektID: String, label: String, quantity: Int) {
        self.objektID = objektID
        self.label = label
        self.quantity = quantity
    }
}

public struct BestellDeckung: Equatable, Sendable {
    public struct Fehlbestand: Equatable, Sendable {
        public let objektID: String
        public let label: String

        public let quantity: Int
    }

    public let fehlend: [Fehlbestand]

    public let ueberbestellt: [Fehlbestand]

    public let freiePositionen: [BestellPosition]

    public let gedeckt: Int
    public let korbGesamt: Int

    public var vollstaendig: Bool { fehlend.isEmpty && korbGesamt > 0 }
}

public enum BestellDeckungsCheck {
    public static func pruefe(korb: [BestellKorbPosition],
                              orders: [Order]) -> BestellDeckung {
        var bestelltJeObjekt: [String: Int] = [:]
        var freie: [BestellPosition] = []
        for order in orders {
            for position in order.positionen {
                if position.objektID.isEmpty {
                    freie.append(position)
                } else {
                    bestelltJeObjekt[position.objektID, default: 0] += position.quantity
                }
            }
        }

        var fehlend: [BestellDeckung.Fehlbestand] = []
        var ueber: [BestellDeckung.Fehlbestand] = []
        var gedeckt = 0
        var gesehen: Set<String> = []
        for korbPosition in korb {
            gesehen.insert(korbPosition.objektID)
            let bestellt = bestelltJeObjekt[korbPosition.objektID] ?? 0
            if bestellt < korbPosition.quantity {
                fehlend.append(.init(objektID: korbPosition.objektID,
                                     label: korbPosition.label,
                                     quantity: korbPosition.quantity - bestellt))
            } else if bestellt > korbPosition.quantity {
                ueber.append(.init(objektID: korbPosition.objektID,
                                   label: korbPosition.label,
                                   quantity: bestellt - korbPosition.quantity))
                gedeckt += 1
            } else {
                gedeckt += 1
            }
        }

        for (objektID, quantity) in bestelltJeObjekt where gesehen.contains(objektID) == false {
            let label = orders
                .flatMap(\.positionen)
                .first { $0.objektID == objektID }?.label ?? objektID
            ueber.append(.init(objektID: objektID, label: label, quantity: quantity))
        }

        return BestellDeckung(
            fehlend: fehlend.sorted { $0.label < $1.label },
            ueberbestellt: ueber.sorted { $0.label < $1.label },
            freiePositionen: freie,
            gedeckt: gedeckt,
            korbGesamt: korb.count)
    }

    public static func lieferfenster(_ orders: [Order]) -> (fruehester: Date, spaetester: Date)? {
        let termine = orders.filter { $0.status != .geliefert }.compactMap(\.liefertermin)
        guard let min = termine.min(), let max = termine.max() else { return nil }
        return (min, max)
    }
}
