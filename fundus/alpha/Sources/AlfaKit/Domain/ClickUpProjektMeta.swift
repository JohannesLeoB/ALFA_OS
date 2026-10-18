import Foundation

public struct ClickUpProjektMeta: Codable, Equatable, Sendable {
    enum CodingKeys: String, CodingKey { case budget, angebotsdatum, auftragsdatum, naechstesNachfassen, driveOrdner, customer = "kunde", kundeToken, projekttyp, ort, lead, lieferanten, risikoEngpass, slackChannel, nachname, vorname, firmenname, email, telefon, angebotsadresseStrasse, angebotsadressePLZ, angebotsadresseOrt, projektadresseStrasse, projektadressePLZ, projektadresseOrt }

    public var budget: Double?

    public var angebotsdatum: Date?

    public var auftragsdatum: Date?

    public var naechstesNachfassen: Date?

    public var driveOrdner: String?

    public var customer: String?

    public var kundeToken: String?

    public var projekttyp: String?

    public var ort: String?

    public var lead: String?

    public var lieferanten: [String]?

    public var risikoEngpass: String?

    public var slackChannel: String?

    public var nachname: String?
    public var vorname: String?
    public var firmenname: String?
    public var email: String?
    public var telefon: String?
    public var angebotsadresseStrasse: String?
    public var angebotsadressePLZ: String?
    public var angebotsadresseOrt: String?
    public var projektadresseStrasse: String?
    public var projektadressePLZ: String?
    public var projektadresseOrt: String?

    public init(
        budget: Double? = nil,
        angebotsdatum: Date? = nil,
        auftragsdatum: Date? = nil,
        naechstesNachfassen: Date? = nil,
        driveOrdner: String? = nil,
        customer: String? = nil,
        kundeToken: String? = nil,
        projekttyp: String? = nil,
        ort: String? = nil,
        lead: String? = nil,
        lieferanten: [String]? = nil,
        risikoEngpass: String? = nil,
        slackChannel: String? = nil,
        nachname: String? = nil,
        vorname: String? = nil,
        firmenname: String? = nil,
        email: String? = nil,
        telefon: String? = nil,
        angebotsadresseStrasse: String? = nil,
        angebotsadressePLZ: String? = nil,
        angebotsadresseOrt: String? = nil,
        projektadresseStrasse: String? = nil,
        projektadressePLZ: String? = nil,
        projektadresseOrt: String? = nil
    ) {
        self.budget = budget
        self.angebotsdatum = angebotsdatum
        self.auftragsdatum = auftragsdatum
        self.naechstesNachfassen = naechstesNachfassen
        self.driveOrdner = driveOrdner
        self.customer = customer
        self.kundeToken = kundeToken
        self.projekttyp = projekttyp
        self.ort = ort
        self.lead = lead
        self.lieferanten = lieferanten
        self.risikoEngpass = risikoEngpass
        self.slackChannel = slackChannel
        self.nachname = nachname
        self.vorname = vorname
        self.firmenname = firmenname
        self.email = email
        self.telefon = telefon
        self.angebotsadresseStrasse = angebotsadresseStrasse
        self.angebotsadressePLZ = angebotsadressePLZ
        self.angebotsadresseOrt = angebotsadresseOrt
        self.projektadresseStrasse = projektadresseStrasse
        self.projektadressePLZ = projektadressePLZ
        self.projektadresseOrt = projektadresseOrt
    }

    public static let empty = ClickUpProjektMeta()

    public var isEmpty: Bool { self == ClickUpProjektMeta.empty }
}

public enum ClickUpMetaSlot: String, CaseIterable, Codable, Sendable {
    case budget
    case angebotsdatum
    case auftragsdatum
    case naechstesNachfassen
    case driveOrdner
    case customer
    case kundeToken
    case projekttyp
    case ort
    case lead
    case lieferanten
    case risikoEngpass
    case slackChannel

    case nachname
    case vorname
    case firmenname
    case email
    case telefon
    case angebotsadresseStrasse
    case angebotsadressePLZ
    case angebotsadresseOrt
    case projektadresseStrasse
    case projektadressePLZ
    case projektadresseOrt

    public enum Kind: Sendable {
        case zahl
        case date
        case text
        case textListe
    }

    public var kind: Kind {
        switch self {
        case .budget:
            return .zahl
        case .angebotsdatum, .auftragsdatum, .naechstesNachfassen:
            return .date
        case .lieferanten:
            return .textListe
        case .driveOrdner, .customer, .kundeToken, .projekttyp, .ort, .lead,
             .risikoEngpass, .slackChannel,
             .nachname, .vorname, .firmenname, .email, .telefon,
             .angebotsadresseStrasse, .angebotsadressePLZ, .angebotsadresseOrt,
             .projektadresseStrasse, .projektadressePLZ, .projektadresseOrt:
            return .text
        }
    }

    public var doubleKeyPath: WritableKeyPath<ClickUpProjektMeta, Double?>? {
        switch self {
        case .budget: return \.budget
        default:      return nil
        }
    }

    public var dateKeyPath: WritableKeyPath<ClickUpProjektMeta, Date?>? {
        switch self {
        case .angebotsdatum:       return \.angebotsdatum
        case .auftragsdatum:       return \.auftragsdatum
        case .naechstesNachfassen: return \.naechstesNachfassen
        default:                   return nil
        }
    }

    public var textKeyPath: WritableKeyPath<ClickUpProjektMeta, String?>? {
        switch self {
        case .driveOrdner:   return \.driveOrdner
        case .customer:         return \.customer
        case .kundeToken:    return \.kundeToken
        case .projekttyp:    return \.projekttyp
        case .ort:           return \.ort
        case .lead:          return \.lead
        case .risikoEngpass: return \.risikoEngpass
        case .slackChannel:  return \.slackChannel
        case .nachname:                 return \.nachname
        case .vorname:                  return \.vorname
        case .firmenname:               return \.firmenname
        case .email:                    return \.email
        case .telefon:                  return \.telefon
        case .angebotsadresseStrasse:   return \.angebotsadresseStrasse
        case .angebotsadressePLZ:       return \.angebotsadressePLZ
        case .angebotsadresseOrt:       return \.angebotsadresseOrt
        case .projektadresseStrasse:    return \.projektadresseStrasse
        case .projektadressePLZ:        return \.projektadressePLZ
        case .projektadresseOrt:        return \.projektadresseOrt
        default:             return nil
        }
    }

    public var listKeyPath: WritableKeyPath<ClickUpProjektMeta, [String]?>? {
        switch self {
        case .lieferanten: return \.lieferanten
        default:           return nil
        }
    }
}

public struct ClickUpFieldRoute: Codable, Hashable, Sendable, Identifiable {
    enum CodingKeys: String, CodingKey { case routeID, source = "quelle", target = "ziel", isActive = "aktiv" }

    public var id: String { routeID }

    public let routeID: String

    public let source: String

    public let target: ClickUpMetaSlot

    public var isActive: Bool

    public init(routeID: String, source: String, target: ClickUpMetaSlot, isActive: Bool = true) {
        self.routeID = routeID
        self.source = source
        self.target = target
        self.isActive = isActive
    }
}

public struct ClickUpFieldRouteRegistry: Codable, Sendable {
    public var routes: [ClickUpFieldRoute]

    public init(routes: [ClickUpFieldRoute]) {
        self.routes = routes
    }

    public var aktiveRoutes: [ClickUpFieldRoute] {
        routes.filter(\.isActive)
    }

    public func route(fuerQuelle feldName: String) -> ClickUpFieldRoute? {
        routes.first { $0.isActive && $0.source == feldName }
    }

    public static let `default` = ClickUpFieldRouteRegistry(routes: [
        ClickUpFieldRoute(routeID: "CU_META_BUDGET", source: "Budget (€)", target: .budget),
        ClickUpFieldRoute(routeID: "CU_META_ANGEBOTSDATUM", source: "Angebotsdatum", target: .angebotsdatum),
        ClickUpFieldRoute(routeID: "CU_META_AUFTRAGSDATUM", source: "Auftragsdatum", target: .auftragsdatum),
        ClickUpFieldRoute(routeID: "CU_META_NACHFASSEN", source: "Nächstes Nachfassen", target: .naechstesNachfassen),
        ClickUpFieldRoute(routeID: "CU_META_DRIVE", source: "Drive-Ordner", target: .driveOrdner),
        ClickUpFieldRoute(routeID: "CU_META_KUNDE", source: "Kunde", target: .customer),
        ClickUpFieldRoute(routeID: "CU_META_KUNDE_TOKEN", source: "Kunde-Token", target: .kundeToken),
        ClickUpFieldRoute(routeID: "CU_META_PROJEKTTYP", source: "Projekttyp", target: .projekttyp),
        ClickUpFieldRoute(routeID: "CU_META_ORT", source: "Ort", target: .ort),
        ClickUpFieldRoute(routeID: "CU_META_LEAD", source: "Lead", target: .lead),
        ClickUpFieldRoute(routeID: "CU_META_LIEFERANTEN", source: "Lieferanten", target: .lieferanten),
        ClickUpFieldRoute(routeID: "CU_META_RISIKO", source: "Risiko/Engpass", target: .risikoEngpass),
        ClickUpFieldRoute(routeID: "CU_META_SLACK", source: "Slack-Channel", target: .slackChannel),

        ClickUpFieldRoute(routeID: "CU_META_NACHNAME", source: "Nachname", target: .nachname),
        ClickUpFieldRoute(routeID: "CU_META_VORNAME", source: "Vorname (mit Titel bei Bedarf)", target: .vorname),
        ClickUpFieldRoute(routeID: "CU_META_FIRMENNAME", source: "Firmenname", target: .firmenname),
        ClickUpFieldRoute(routeID: "CU_META_EMAIL", source: "E-Mail", target: .email),
        ClickUpFieldRoute(routeID: "CU_META_TELEFON", source: "Telefon 1", target: .telefon),
        ClickUpFieldRoute(
            routeID: "CU_META_ANGEBOTSADRESSE_STRASSE", source: "Angebotsadresse Straße + Hausnummer",
            target: .angebotsadresseStrasse),
        ClickUpFieldRoute(routeID: "CU_META_ANGEBOTSADRESSE_PLZ", source: "Angebotsadresse PLZ", target: .angebotsadressePLZ),
        ClickUpFieldRoute(routeID: "CU_META_ANGEBOTSADRESSE_ORT", source: "Angebotsadresse Ort", target: .angebotsadresseOrt),
        ClickUpFieldRoute(
            routeID: "CU_META_PROJEKTADRESSE_STRASSE", source: "Projektadresse Straße + Hausnummer",
            target: .projektadresseStrasse),
        ClickUpFieldRoute(routeID: "CU_META_PROJEKTADRESSE_PLZ", source: "Projektadresse PLZ", target: .projektadressePLZ),
        ClickUpFieldRoute(routeID: "CU_META_PROJEKTADRESSE_ORT", source: "Projektadresse Ort", target: .projektadresseOrt)
    ])
}
