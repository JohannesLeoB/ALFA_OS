import Foundation
import MykilosKit

public struct GoldenKundeEingabe: Sendable, Equatable {
    public let vorname: String
    public let nachname: String
    public let firma: String
    public let email: String
    public let telefon: String
    public let strasse: String

    public let houseNumber: String
    public let plz: String
    public let ort: String

    public let projektnummerApp: String

    public let importBatch: String

    public let customerNumber: String?

    public init(vorname: String, nachname: String, firma: String, email: String,
                telefon: String, strasse: String, houseNumber: String = "",
                plz: String, ort: String,
                projektnummerApp: String, importBatch: String, customerNumber: String? = nil) {
        self.vorname = vorname
        self.nachname = nachname
        self.firma = firma
        self.email = email
        self.telefon = telefon
        self.strasse = strasse
        self.houseNumber = houseNumber
        self.plz = plz
        self.ort = ort
        self.projektnummerApp = projektnummerApp
        self.importBatch = importBatch
        self.customerNumber = customerNumber
    }
}

public enum GoldenKundeMapper {
    static let feldFirmaName    = "Firma / Name"
    static let feldVorname      = "Vorname"
    static let feldNachname     = "Nachname"
    static let feldStrasse      = "Straße"

    static let feldHausnummer   = "Hausnummer"
    static let feldPLZ          = "PLZ"
    static let feldOrt          = "Ort"
    static let feldEmail        = "E-Mail"
    static let feldTelefon      = "Telefon"
    static let feldQuellen      = "Quellen"
    static let feldImportBatch  = "Import-Batch"
    static let feldNotizen      = "Notizen"
    static let fieldCustomerNumber = "Kundennummer"
    static let feldWeclappID    = "WeClapp-ID"

    static let quelleManuell = "Manuell"

    public static func felder(_ e: GoldenKundeEingabe) -> [String: AirtableFieldValue] {
        let vollname = "\(e.vorname) \(e.nachname)".trimmingCharacters(in: .whitespaces)
        let display = e.firma.isEmpty ? (vollname.isEmpty ? "Kunde" : vollname) : e.firma
        var f: [String: AirtableFieldValue] = [
            feldFirmaName: .string(display),
            feldQuellen: .array([quelleManuell])
        ]
        if let nr = e.customerNumber, nr.isEmpty == false { f[fieldCustomerNumber] = .string(nr) }
        if e.vorname.isEmpty == false { f[feldVorname] = .string(e.vorname) }
        if e.nachname.isEmpty == false { f[feldNachname] = .string(e.nachname) }
        if e.strasse.isEmpty == false { f[feldStrasse] = .string(e.strasse) }
        if e.houseNumber.isEmpty == false { f[feldHausnummer] = .string(e.houseNumber) }
        if e.plz.isEmpty == false { f[feldPLZ] = .string(e.plz) }
        if e.ort.isEmpty == false { f[feldOrt] = .string(e.ort) }
        if e.email.isEmpty == false { f[feldEmail] = .string(e.email) }
        if e.telefon.isEmpty == false { f[feldTelefon] = .string(e.telefon) }
        if e.importBatch.isEmpty == false { f[feldImportBatch] = .string(e.importBatch) }

        if e.projektnummerApp.isEmpty == false {
            f[feldNotizen] = .string(
                "Angelegt aus mykilOS-Projektanlage · Projekt \(e.projektnummerApp). "
                + "Kundennummer folgt bei echter WeClapp-Anlage.")
        }
        return f
    }
}

public enum GoldenKundennummerVergabe {
    public static func naechste(ausBestehenden numbers: [String]) -> String? {
        let values = numbers.compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard let hoechste = values.max() else { return nil }
        return String(hoechste + 1)
    }
}

public enum GoldenKundeDedup {
    public static func findeBestehenden(
        in records: [[String: AirtableFieldValue]], email: String?, telefon: String?
    ) -> String? {
        let mail = email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let tel = normTel(telefon)
        guard (mail?.isEmpty == false) || (tel?.isEmpty == false) else { return nil }
        for record in records {
            if let mail, mail.isEmpty == false,
               record["E-Mail"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == mail {
                return record["_airtableRecordID"]?.stringValue
            }
            if let tel, tel.isEmpty == false, normTel(record["Telefon"]?.stringValue) == tel {
                return record["_airtableRecordID"]?.stringValue
            }
        }
        return nil
    }

    static func normTel(_ raw: String?) -> String? {
        guard let raw else { return nil }
        var d = raw.filter(\.isNumber)
        guard d.isEmpty == false else { return nil }
        if d.hasPrefix("0049") { d = String(d.dropFirst(2)) }
        if d.hasPrefix("49") { d = "0" + d.dropFirst(2) }
        return d
    }
}

public struct GoldenKundeAirtableWriter: Sendable {
    public static let baseID = CompanySetup.valueOrEmpty("airtable.base.golden_customers")

    public static let tableID = CompanySetup.valueOrEmpty("airtable.table.golden_customers")

    private let writer: AirtableBestEffortWriter

    public init(creator: any AirtableRecordCreating) {
        self.writer = AirtableBestEffortWriter(creator: creator)
    }

    public func schreibe(_ input: GoldenKundeEingabe) async -> AirtableWriteOutcome {
        await writer.schreibe(baseID: Self.baseID, table: Self.tableID, felder: GoldenKundeMapper.felder(input))
    }
}
