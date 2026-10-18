import Foundation
import AlfaKit

public struct WeitereKontaktEingabe: Sendable, Equatable {
    public let name: String
    public let organisation: String?
    public let email: String?
    public let telefon: String?
    public let adresse: String?
    public let kategorie: String?

    public let projektnummer: String?

    public let quellKontaktIDMM: String?

    public init(name: String, organisation: String? = nil, email: String? = nil,
                telefon: String? = nil, adresse: String? = nil, kategorie: String? = nil,
                projektnummer: String? = nil, quellKontaktIDMM: String? = nil) {
        self.name = name
        self.organisation = organisation
        self.email = email
        self.telefon = telefon
        self.adresse = adresse
        self.kategorie = kategorie
        self.projektnummer = projektnummer
        self.quellKontaktIDMM = quellKontaktIDMM
    }
}

public enum WeitereKontaktMapper {
    static let feldFirmaName    = "Firma / Name"
    static let feldOrganisation = "Organisation"
    static let feldEmail        = "E-Mail"
    static let feldTelefon      = "Telefon"
    static let feldKategorie    = "Kategorie"
    static let fieldSource       = "Quelle"
    static let feldQuellIDMM    = "Quell-Kontakt-ID (MM)"
    static let feldNotiz        = "Notiz"
    static let feldProjektNr    = "Projekt (Nummer)"
    static let quelleMarker     = "mykilOS"

    public static func felder(_ e: WeitereKontaktEingabe) -> [String: AirtableFieldValue] {
        var f: [String: AirtableFieldValue] = [
            feldFirmaName: .string(e.name.isEmpty ? "Kontakt" : e.name),
            fieldSource: .string(quelleMarker)
        ]
        if let v = e.organisation, v.isEmpty == false { f[feldOrganisation] = .string(v) }
        if let v = e.email, v.isEmpty == false { f[feldEmail] = .string(v) }
        if let v = e.telefon, v.isEmpty == false { f[feldTelefon] = .string(v) }
        if let v = e.kategorie, v.isEmpty == false { f[feldKategorie] = .string(v) }
        if let v = e.projektnummer, v.isEmpty == false { f[feldProjektNr] = .string(v) }
        if let v = e.quellKontaktIDMM, v.isEmpty == false { f[feldQuellIDMM] = .string(v) }
        if let v = e.adresse, v.isEmpty == false { f[feldNotiz] = .string("Adresse: \(v)") }
        return f
    }
}

public struct WeitereKontaktAirtableWriter: Sendable {
    public static let baseID = CompanySetup.valueOrEmpty("airtable.base.golden_customers")

    public static let tableID = CompanySetup.valueOrEmpty("airtable.table.contacts")

    private let writer: AirtableBestEffortWriter

    public init(creator: any AirtableRecordCreating) {
        self.writer = AirtableBestEffortWriter(creator: creator)
    }

    public func schreibe(_ input: WeitereKontaktEingabe) async -> AirtableWriteOutcome {
        await writer.schreibe(baseID: Self.baseID, table: Self.tableID, felder: WeitereKontaktMapper.felder(input))
    }
}
