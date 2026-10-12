import Foundation
import MykilosKit

public struct AirtableKatalogPosition: Sendable, Equatable, Codable, Identifiable {
    enum CodingKeys: String, CodingKey { case code, name, group = "gruppe", status, quellgeprueft, belegURL }

    public let code: String
    public let name: String
    public let group: String?

    public let status: String
    public let quellgeprueft: Bool
    public let belegURL: String?

    public var id: String { code }

    public init(code: String, name: String, group: String?, status: String,
                quellgeprueft: Bool, belegURL: String?) {
        self.code = code
        self.name = name
        self.group = group
        self.status = status
        self.quellgeprueft = quellgeprueft
        self.belegURL = belegURL
    }
}

public struct AirtableKatalog: Sendable, Equatable, Codable, Identifiable {
    public let id: String
    public let hersteller: String
    public let produktlinie: String

    public let kategorieName: String?
    public let quelleWebseite: String?
    public let quelleStand: String?
    public let positionen: [AirtableKatalogPosition]

    public init(id: String, hersteller: String, produktlinie: String, kategorieName: String?,
                quelleWebseite: String?, quelleStand: String?, positionen: [AirtableKatalogPosition]) {
        self.id = id
        self.hersteller = hersteller
        self.produktlinie = produktlinie
        self.kategorieName = kategorieName
        self.quelleWebseite = quelleWebseite
        self.quelleStand = quelleStand
        self.positionen = positionen
    }
}

@MainActor
@Observable
public final class PapersKatalogStore {
    public enum LoadState: Equatable {
        case idle
        case loading
        case content([AirtableKatalog])
        case empty
        case notConnected
        case error(String)
    }

    public private(set) var state: LoadState = .idle

    public var alleKataloge: [AirtableKatalog] {
        if case .content(let items) = state { return items }
        return []
    }

    public var istGeladen: Bool {
        if case .content = state { return true }
        return false
    }

    public static let baseID = CompanySetup.valueOrEmpty("airtable.base.media_library")
    nonisolated static let tableKategorien = "Kategorien"
    nonisolated static let tableHersteller = "Hersteller"
    nonisolated static let tableKataloge = "Kataloge"
    nonisolated static let tableKatalogpositionen = "Katalogpositionen"

    nonisolated static let feldNamePrimaer = "Name"

    nonisolated static let feldKatalogeHersteller = "Hersteller"
    nonisolated static let feldKatalogeProduktlinie = "Produktlinie"
    nonisolated static let feldKatalogeKategorie = "Kategorie"
    nonisolated static let feldKatalogeQuelleWebseite = "Quelle-Webseite"
    nonisolated static let feldKatalogeQuelleStand = "Quelle-Stand"

    nonisolated static let feldPositionCode = "Code"
    nonisolated static let feldPositionName = "Name"
    nonisolated static let feldPositionKatalog = "Katalog"
    nonisolated static let feldPositionGruppe = "Gruppe"
    nonisolated static let feldPositionStatus = "Status"
    nonisolated static let feldPositionQuellgeprueft = "Quellgeprüft"
    nonisolated static let feldPositionBelegURL = "Beleg-URL"

    private let client: AirtableFetching
    private let cache: FileBackedRepository<AirtableKatalog>?

    public init(client: AirtableFetching = AirtableClient(), cacheDirectory: URL? = nil) {
        self.client = client
        self.cache = try? FileBackedRepository<AirtableKatalog>(filename: "papers_kataloge_cache", directory: cacheDirectory ?? DatenRoot.root())
    }

    public func load() async {
        switch state {
        case .content, .loading: return
        default: break
        }
        if let cached = try? cache?.loadAll(), !cached.isEmpty {
            state = .content(cached)
            await fetchAll(showLoadingState: false)
        } else {
            state = .loading
            await fetchAll(showLoadingState: true)
        }
    }

    public func reload() async {
        state = .loading
        await fetchAll(showLoadingState: true)
    }

    private func fetchAll(showLoadingState: Bool) async {
        do {
            async let kategorienRecords = client.fetchRecords(baseID: Self.baseID, table: Self.tableKategorien)
            async let herstellerRecords = client.fetchRecords(baseID: Self.baseID, table: Self.tableHersteller)
            async let katalogeRecords = client.fetchRecords(baseID: Self.baseID, table: Self.tableKataloge)
            async let positionenRecords = client.fetchRecords(baseID: Self.baseID, table: Self.tableKatalogpositionen)
            let (kategorien, hersteller, kataloge, positionen) =
                try await (kategorienRecords, herstellerRecords, katalogeRecords, positionenRecords)

            let mapped = await Task.detached(priority: .userInitiated) {
                Self.mapKataloge(kategorien: kategorien, hersteller: hersteller,
                                 kataloge: kataloge, positionen: positionen)
            }.value

            if mapped.isEmpty {
                if showLoadingState {
                    state = kataloge.isEmpty ? .empty
                        : .error("Kataloge geladen (\(kataloge.count)), aber keiner konnte gemappt werden — Feld-Namen prüfen.")
                }
            } else {
                state = .content(mapped)
                try? cache?.saveAll(mapped)
            }
        } catch AirtableError.notConnected {
            if showLoadingState { state = .notConnected }
        } catch AirtableError.httpError(let code) {
            if showLoadingState { state = .error("HTTP \(code) — Airtable nicht erreichbar oder Base-ID falsch.") }
        } catch AirtableError.decodingFailed {
            if showLoadingState { state = .error("Antwort konnte nicht dekodiert werden — API-Format geändert?") }
        } catch {
            if showLoadingState { state = .error(error.localizedDescription) }
        }
    }

    nonisolated static func idNameMap(_ records: [[String: AirtableFieldValue]]) -> [String: String] {
        var map: [String: String] = [:]
        for fields in records {
            guard let id = fields["_airtableRecordID"]?.stringValue,
                  let name = fields[feldNamePrimaer]?.stringValue else { continue }
            map[id] = name
        }
        return map
    }

    public nonisolated static func mapKataloge(
        kategorien: [[String: AirtableFieldValue]],
        hersteller: [[String: AirtableFieldValue]],
        kataloge: [[String: AirtableFieldValue]],
        positionen: [[String: AirtableFieldValue]]
    ) -> [AirtableKatalog] {
        let kategorieNamen = idNameMap(kategorien)
        let herstellerNamen = idNameMap(hersteller)

        var positionenJeKatalog: [String: [AirtableKatalogPosition]] = [:]
        for fields in positionen {
            guard let katalogID = fields[feldPositionKatalog]?.firstArrayValue,
                  let code = fields[feldPositionCode]?.anyStringValue,
                  code.trimmingCharacters(in: .whitespaces).isEmpty == false else { continue }
            let position = AirtableKatalogPosition(
                code: code,
                name: fields[feldPositionName]?.stringValue ?? code,
                group: fields[feldPositionGruppe]?.stringValue,
                status: fields[feldPositionStatus]?.stringValue ?? "unbekannt",
                quellgeprueft: fields[feldPositionQuellgeprueft]?.boolValue ?? false,
                belegURL: fields[feldPositionBelegURL]?.stringValue
            )
            positionenJeKatalog[katalogID, default: []].append(position)
        }

        return kataloge.compactMap { fields -> AirtableKatalog? in
            guard let id = fields["_airtableRecordID"]?.stringValue,
                  let produktlinie = fields[feldKatalogeProduktlinie]?.stringValue,
                  produktlinie.trimmingCharacters(in: .whitespaces).isEmpty == false else { return nil }
            let herstellerID = fields[feldKatalogeHersteller]?.firstArrayValue
            let herstellerName = herstellerID.flatMap { herstellerNamen[$0] } ?? "Unbekannter Hersteller"
            let kategorieID = fields[feldKatalogeKategorie]?.firstArrayValue
            return AirtableKatalog(
                id: id,
                hersteller: herstellerName,
                produktlinie: produktlinie,
                kategorieName: kategorieID.flatMap { kategorieNamen[$0] },
                quelleWebseite: fields[feldKatalogeQuelleWebseite]?.stringValue,
                quelleStand: fields[feldKatalogeQuelleStand]?.stringValue,
                positionen: (positionenJeKatalog[id] ?? []).sorted { $0.code < $1.code }
            )
        }
        .sorted { $0.hersteller < $1.hersteller }
    }
}
