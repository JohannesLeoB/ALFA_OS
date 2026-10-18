import Foundation
import AlfaKit

@MainActor
@Observable
public final class LagerlisteStore {
    public enum LoadState: Equatable {
        case idle
        case loading

        case content([LagerItem])
        case empty
        case notConnected
        case error(String)
    }

    public private(set) var state: LoadState = .idle

    public var items: [LagerItem] {
        if case .content(let items) = state { return items }
        return []
    }

    public static let baseID    = CompanySetup.valueOrEmpty("airtable.base.article_catalog")
    public static let tableID   = "Lagerliste"
    public static let tableKey  = CompanySetup.valueOrEmpty("airtable.table.stock_list")

    static let feldBezeichnung   = "Bezeichnung"
    static let feldKategorie     = "Kategorie"
    static let feldHersteller    = "Hersteller"
    static let feldArtikelnummer = "Artikelnummer"
    static let feldBestand       = "Bestand"
    static let feldEKNetto       = "EK netto (€)"
    static let feldVKNetto       = "VK netto (€)"
    static let fieldSource        = "Quelle"
    static let feldNotiz         = "Notiz"

    private let client: AirtableFetching

    public init(client: AirtableFetching = AirtableClient()) {
        self.client = client
    }

    public func load() async {
        guard case .loading = state else {
            state = .loading
            await _fetchAndMap()
            return
        }
    }

    public func reload() async {
        state = .loading
        await _fetchAndMap()
    }

    private func _fetchAndMap() async {
        do {
            let records = try await client.fetchRecords(
                baseID: Self.baseID,
                table: Self.tableID
            )
            let mapped = Self.mapLagerItems(from: records)
            state = mapped.isEmpty ? .empty : .content(mapped)
        } catch AirtableError.notConnected {
            state = .notConnected
        } catch AirtableError.httpError(let code) {
            state = .error("HTTP \(code)")
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    public nonisolated static func mapLagerItems(
        from records: [[String: AirtableFieldValue]]
    ) -> [LagerItem] {
        records.compactMap { fields in
            guard let label = fields[feldBezeichnung]?.stringValue,
                  !label.trimmingCharacters(in: .whitespaces).isEmpty else {
                return nil
            }
            let recordID = fields["_airtableRecordID"]?.stringValue ?? label
            let bestandRaw = fields[feldBestand]?.numberValue
            return LagerItem(
                id: recordID,
                label: label,
                kategorie: fields[feldKategorie]?.stringValue,
                hersteller: fields[feldHersteller]?.stringValue,
                articleNumber: fields[feldArtikelnummer]?.stringValue,
                stock: bestandRaw.map { Int($0) },
                ekNetto: fields[feldEKNetto]?.numberValue,
                vkNetto: fields[feldVKNetto]?.numberValue,
                source: fields[fieldSource]?.stringValue,
                notiz: fields[feldNotiz]?.stringValue
            )
        }
    }
}
