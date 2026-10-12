import Foundation
import MykilosKit

public struct ArtikelPreisKorrektur: Sendable, Equatable {
    public let ekNetto: Double?
    public let vkNetto: Double?

    public init(ekNetto: Double?, vkNetto: Double?) {
        self.ekNetto = ekNetto
        self.vkNetto = vkNetto
    }
}

public enum ArtikelPreisErgebnis: Sendable, Equatable {
    case geschrieben(ArtikelItem)
    case schlaeft
    case error(String)
}

public struct ArtikelPreisPort: Sendable {
    public static let baseID  = CompanySetup.valueOrEmpty("airtable.base.article_catalog")
    public static let tableID = CompanySetup.valueOrEmpty("airtable.table.article_catalog")

    static let feldEKNetto = "Netto-EK (€)"
    static let feldVKNetto = "Netto-VK MYKILOS (€)"

    private let update: AirtableRecordUpdating

    public init(update: AirtableRecordUpdating = AirtableClient()) {
        self.update = update
    }

    public static func felder(_ korrektur: ArtikelPreisKorrektur) -> [String: AirtableFieldValue] {
        var felder: [String: AirtableFieldValue] = [:]
        if let ek = korrektur.ekNetto { felder[feldEKNetto] = .number(ek) }
        if let vk = korrektur.vkNetto { felder[feldVKNetto] = .number(vk) }
        return felder
    }

    public static var istWach: Bool {
        AirtableClient.isWritable(baseID: baseID, table: tableID)
    }

    public func schreibeKorrektur(
        artikel: ArtikelItem, korrektur: ArtikelPreisKorrektur
    ) async -> ArtikelPreisErgebnis {
        guard artikel.id.isEmpty == false else { return .error("leere Record-ID") }
        guard korrektur.ekNetto != nil || korrektur.vkNetto != nil else {
            return .error("keine Änderung")
        }
        let felder = Self.felder(korrektur)
        do {
            try await update.updateRecord(
                baseID: Self.baseID, table: Self.tableID, recordID: artikel.id, fields: felder)
            let newState = ArtikelItem(
                id: artikel.id,
                articleNumber: artikel.articleNumber,
                hersteller: artikel.hersteller,
                kategorie: artikel.kategorie,
                artikelbeschreibung: artikel.artikelbeschreibung,
                ean: artikel.ean,
                ekNetto: korrektur.ekNetto ?? artikel.ekNetto,
                vkNetto: korrektur.vkNetto ?? artikel.vkNetto,
                produktbildURL: artikel.produktbildURL,
                reviewZustand: artikel.reviewZustand,
                sevDeskArtikelID: artikel.sevDeskArtikelID,
                widthMm: artikel.widthMm,
                heightMm: artikel.heightMm,
                tiefeMm: artikel.tiefeMm,
                gewichtGramm: artikel.gewichtGramm
            )
            return .geschrieben(newState)
        } catch let error as AirtableError {
            if case .invalidBaseID = error { return .schlaeft }
            return .error(String(describing: error))
        } catch {
            return .error(String(describing: error))
        }
    }
}
