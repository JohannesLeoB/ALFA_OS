import Foundation
import AlfaKit

public enum ArtikelReviewVerdikt: String, Sendable, Equatable, CaseIterable {
    case verifiziert
    case beanstandet
}

public enum ArtikelReviewVerdiktErgebnis: Sendable, Equatable {
    case geschrieben
    case schlaeft
    case error(String)
}

public struct ArtikelReviewVerdiktPort: Sendable {
    public static let baseID  = CompanySetup.valueOrEmpty("airtable.base.article_catalog")
    public static let tableID = CompanySetup.valueOrEmpty("airtable.table.article_catalog")

    static let feldReviewStatus   = "Review-Status"
    static let feldVerifiziert    = "Verifiziert"
    static let feldVerifiziertVon = "Verifiziert von"
    static let feldVerifiziertAm  = "Verifiziert am"

    static let feldNettoEK        = "Netto-EK (€)"
    static let feldNettoVKListe   = "Netto-Listen-VK (€)"
    static let feldMargeProzent   = "Marge manuell gesetzt %"
    static let feldMargeVon       = "Marge manuell gesetzt von"
    static let feldMargeAm        = "Marge manuell gesetzt am"

    private let update: AirtableRecordUpdating

    public init(update: AirtableRecordUpdating = AirtableClient()) {
        self.update = update
    }

    public static func felder(
        verdikt: ArtikelReviewVerdikt, pruefer: String, amISO: String,
        marge: ArtikelManuelleMarge? = nil
    ) -> [String: AirtableFieldValue] {
        switch verdikt {
        case .verifiziert:
            var f: [String: AirtableFieldValue] = [
                feldReviewStatus: .string(ArtikelReviewStatus.verifiziert.airtableWert),
                feldVerifiziert: .bool(true),
                feldVerifiziertVon: .string(pruefer),
                feldVerifiziertAm: .string(amISO)
            ]
            if let marge {
                f[marge.betrifftEK ? feldNettoEK : feldNettoVKListe] = .number(marge.berechneterWert)
                f[feldMargeProzent] = .number(marge.rabattProzent / 100)
                f[feldMargeVon] = .string(pruefer)
                f[feldMargeAm] = .string(amISO)
            }
            return f
        case .beanstandet:
            return [
                feldReviewStatus: .string(ArtikelReviewStatus.beanstandet.airtableWert)
            ]
        }
    }

    public static var istWach: Bool {
        AirtableClient.isWritable(baseID: baseID, table: tableID)
    }

    public static func isoZeitstempel(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: date)
    }

    public func schreibeVerdikt(
        recordID: String, verdikt: ArtikelReviewVerdikt,
        pruefer: String, am: Date, marge: ArtikelManuelleMarge? = nil
    ) async -> ArtikelReviewVerdiktErgebnis {
        guard recordID.isEmpty == false else { return .error("leere Record-ID") }
        let felder = Self.felder(verdikt: verdikt, pruefer: pruefer, amISO: Self.isoZeitstempel(am), marge: marge)
        do {
            try await update.updateRecord(
                baseID: Self.baseID, table: Self.tableID, recordID: recordID, fields: felder)
            return .geschrieben
        } catch let error as AirtableError {
            if case .invalidBaseID = error { return .schlaeft }
            return .error(String(describing: error))
        } catch {
            return .error(String(describing: error))
        }
    }
}
