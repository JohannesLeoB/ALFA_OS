import Foundation
import AlfaKit

@MainActor
@Observable
public final class WarenkorbListeStore {
    public enum LoadState: Equatable {
        case idle
        case loading
        case content([WarenkorbEintrag])
        case empty
        case notConnected
        case error(String)
    }

    public private(set) var state: LoadState = .idle

    public var entries: [WarenkorbEintrag] {
        if case .content(let items) = state { return items }
        return []
    }

    public static let baseID    = CompanySetup.valueOrEmpty("airtable.base.checkout_cart")
    public static let tableID   = "Warenkörbe"
    public static let tableKey  = CompanySetup.valueOrEmpty("airtable.table.cart_list")

    static let feldBezeichnung      = "Bezeichnung"
    static let feldProjekt          = "Projekt"
    static let feldStatus           = "Status"
    static let feldVersion          = "Version"
    static let feldErstelltAm       = "Erstellt-am"
    static let feldAnzahlPositionen = "Anzahl Positionen"
    static let feldGesamtEK         = "Gesamt EK (€)"
    static let feldGesamtVK         = "Gesamt VK (€)"
    static let feldPositionenJSON   = "Positionen (JSON)"

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
            let mapped = Self.mapEintraege(from: records)
                .sorted { lhs, rhs in

                    if let l = lhs.erstelltAm, let r = rhs.erstelltAm {
                        return l > r
                    }
                    return lhs.version > rhs.version
                }
            state = mapped.isEmpty ? .empty : .content(mapped)
        } catch AirtableError.notConnected {
            state = .notConnected
        } catch AirtableError.httpError(let code) {
            state = .error("HTTP \(code)")
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoFormatterShort: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    public nonisolated static func mapEintraege(
        from records: [[String: AirtableFieldValue]]
    ) -> [WarenkorbEintrag] {
        records.compactMap { fields in

            guard let label = fields[feldBezeichnung]?.anyStringValue,
                  !label.trimmingCharacters(in: .whitespaces).isEmpty else {
                return nil
            }
            let recordID = fields["_airtableRecordID"]?.stringValue ?? label

            let erstelltAm: Date? = {
                guard let dateStr = fields[feldErstelltAm]?.stringValue else { return nil }
                return isoFormatter.date(from: dateStr)
                    ?? isoFormatterShort.date(from: dateStr)
            }()

            let projekt = fields[feldProjekt]?.firstArrayValue
                ?? fields[feldProjekt]?.anyStringValue

            let version = fields[feldVersion]?.numberValue.map { Int($0) } ?? 1

            return WarenkorbEintrag(
                id: recordID,
                label: label,
                projekt: projekt,
                status: fields[feldStatus]?.stringValue ?? "Aktuell",
                version: version,
                erstelltAm: erstelltAm,
                anzahlPositionen: fields[feldAnzahlPositionen]?.numberValue.map { Int($0) },
                totalEK: fields[feldGesamtEK]?.numberValue,
                totalVk: fields[feldGesamtVK]?.numberValue,
                positionenJSON: fields[feldPositionenJSON]?.stringValue
            )
        }
    }
}
