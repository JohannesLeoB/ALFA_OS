import Foundation
import MykilosKit

public enum AirtableRolle: String, CaseIterable, Sendable {
    case kontakte
    case artikelKatalog
    case projekte
    case checkoutLedger
    case sevdeskBriefkasten
    case clockodoZeitbuchung
    case weclappStammdaten
    case mediathek
    case warenkorb
    case fragebogenIntake
    case datenweichen
    case datenstromLog
    case writeShadow
}

public struct AirtableRoute: Sendable, Equatable {
    public enum Zugriff: Sendable, Equatable {
        case nurLesen
        case anhaengen
        case aktualisieren
    }

    public enum Status: Sendable, Equatable {
        case live
        case geplant
    }

    public let rolle: AirtableRolle
    public let baseID: String

    public let tabelle: String
    public let zugriff: Zugriff
    public let status: Status

    public init(rolle: AirtableRolle, baseID: String, tabelle: String,
                zugriff: Zugriff, status: Status) {
        self.rolle = rolle
        self.baseID = baseID
        self.tabelle = tabelle
        self.zugriff = zugriff
        self.status = status
    }

    public var darfSchreiben: Bool { zugriff != .nurLesen }
}

public enum AirtableRouting {
    public static let kontakte = AirtableRoute(
        rolle: .kontakte, baseID: CompanySetup.valueOrEmpty("airtable.base.golden_customers"), tabelle: CompanySetup.valueOrEmpty("airtable.table.contacts"),
        zugriff: .aktualisieren, status: .live)

    public static let artikelKatalog = AirtableRoute(
        rolle: .artikelKatalog, baseID: CompanySetup.valueOrEmpty("airtable.base.article_catalog"), tabelle: "Artikel",
        zugriff: .nurLesen, status: .live)

    public static let projekte = AirtableRoute(
        rolle: .projekte, baseID: CompanySetup.valueOrEmpty("airtable.base.projects"), tabelle: CompanySetup.valueOrEmpty("airtable.table.projects"),
        zugriff: .aktualisieren, status: .live)

    public static let checkoutLedger = AirtableRoute(
        rolle: .checkoutLedger, baseID: CompanySetup.valueOrEmpty("airtable.base.checkout_cart"), tabelle: "Checkouts",
        zugriff: .anhaengen, status: .live)

    public static let sevdeskBriefkasten = AirtableRoute(
        rolle: .sevdeskBriefkasten, baseID: CompanySetup.valueOrEmpty("airtable.base.sevdesk_postbox"), tabelle: "Commercial Packages",
        zugriff: .anhaengen, status: .live)

    public static let clockodoZeitbuchung = AirtableRoute(
        rolle: .clockodoZeitbuchung, baseID: CompanySetup.valueOrEmpty("airtable.base.clockodo_bookings"), tabelle: "Zeitbuchungen",
        zugriff: .anhaengen, status: .live)

    public static let weclappStammdaten = AirtableRoute(
        rolle: .weclappStammdaten, baseID: CompanySetup.valueOrEmpty("airtable.base.weclapp_masterdata"), tabelle: "*",
        zugriff: .nurLesen, status: .live)

    public static let mediathek = AirtableRoute(
        rolle: .mediathek, baseID: CompanySetup.valueOrEmpty("airtable.base.media_library"), tabelle: "*",
        zugriff: .nurLesen, status: .live)

    public static let warenkorb = AirtableRoute(
        rolle: .warenkorb, baseID: CompanySetup.valueOrEmpty("airtable.base.checkout_cart"), tabelle: "Warenkörbe",
        zugriff: .anhaengen, status: .live)

    public static let fragebogenIntake = AirtableRoute(
        rolle: .fragebogenIntake, baseID: CompanySetup.valueOrEmpty("airtable.base.questionnaire_intake"), tabelle: CompanySetup.valueOrEmpty("airtable.table.questionnaire_intake"),
        zugriff: .anhaengen, status: .live)

    public static let datenweichen = AirtableRoute(
        rolle: .datenweichen, baseID: CompanySetup.valueOrEmpty("airtable.base.data_flow"), tabelle: CompanySetup.valueOrEmpty("airtable.table.data_switches"),
        zugriff: .anhaengen, status: .geplant)

    public static let datenstromLog = AirtableRoute(
        rolle: .datenstromLog, baseID: CompanySetup.valueOrEmpty("airtable.base.data_flow"), tabelle: "Datenstrom-Log",
        zugriff: .anhaengen, status: .live)

    public static let writeShadow = AirtableRoute(
        rolle: .writeShadow, baseID: CompanySetup.valueOrEmpty("airtable.base.write_shadow"), tabelle: "Write-Shadow-Log",
        zugriff: .anhaengen, status: .live)

    public static let alle: [AirtableRoute] = [
        kontakte, artikelKatalog, projekte, checkoutLedger, sevdeskBriefkasten,
        clockodoZeitbuchung, weclappStammdaten, mediathek, warenkorb,
        fragebogenIntake, datenweichen, datenstromLog, writeShadow
    ]

    public static func route(_ rolle: AirtableRolle) -> AirtableRoute {
        alle.first { $0.rolle == rolle }!
    }
}
