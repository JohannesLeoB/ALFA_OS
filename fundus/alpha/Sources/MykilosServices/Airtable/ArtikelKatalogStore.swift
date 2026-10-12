import Foundation
import MykilosKit

@MainActor
@Observable
public final class ArtikelKatalogStore {
    public enum LoadState: Equatable {
        case idle

        case loading(Int)

        case content([ArtikelItem])
        case empty
        case notConnected
        case error(String)
    }

    public private(set) var state: LoadState = .idle

    public var alleArtikel: [ArtikelItem] {
        if case .content(let items) = state { return items }
        return []
    }

    public var istGeladen: Bool {
        if case .content = state { return true }
        return false
    }

    public static let baseID  = CompanySetup.valueOrEmpty("airtable.base.article_catalog_legacy")
    public static let tableID = "Artikel"
    public static let tableKey = CompanySetup.valueOrEmpty("airtable.table.article_catalog_legacy")

    static let feldArtikelnummer    = "Artikelnummer"
    static let feldHersteller       = "Hersteller"
    static let feldKategorie        = "Kategorie"
    static let feldBeschreibung     = "Artikelbeschreibung"
    static let feldEKNetto          = "Netto-Einkaufspreis (€)"
    static let feldVKNetto          = "Netto-Verkaufspreis MYKILOS (€)"
    static let feldProduktbild      = "Automatisches Produktbild (Web-Suche)"
    static let feldEAN              = "EAN/GTIN"

    public static let baseIDNeu  = CompanySetup.valueOrEmpty("airtable.base.article_catalog")
    public static let tableIDNeu = CompanySetup.valueOrEmpty("airtable.table.article_catalog")
    static let herstellerTableNeu = CompanySetup.valueOrEmpty("airtable.table.manufacturers_new")
    static let kategorieTableNeu  = CompanySetup.valueOrEmpty("airtable.table.categories_new")
    static let feldNeuArtikelnummer = "Artikelnummer"
    static let feldNeuHersteller    = "Hersteller"
    static let feldNeuKategorie     = "Kategorie"

    static let feldNeuBezeichnung   = "Bezeichnung"
    static let feldNeuVariante      = "Variante"
    static let feldNeuMasse         = "Maße"
    static let feldNeuBeschreibung  = "Beschreibung"
    static let feldNeuEKNetto       = "Netto-EK (€)"
    static let feldNeuVKNetto       = "Netto-VK MYKILOS (€)"
    static let feldNeuBildURL       = "Bild-URL"
    static let feldNeuEAN           = "EAN/GTIN"
    static let feldNeuSevDeskArtikelID = "sevDesk Artikel-ID"

    static let feldNeuBreiteMm      = "Breite mm"
    static let feldNeuHoeheMm       = "Höhe mm"
    static let feldNeuTiefeMm       = "Tiefe mm"
    static let feldNeuGewichtG      = "Gewicht g"

    static let feldKategorieName    = "Name"
    static let feldOberkategorie    = "Oberkategorie"
    static let feldSynonyme         = "Synonyme"

    public private(set) var vocabulary: SearchVocabulary = .empty

    private var searchIndex: ArticleSearchIndex?

    private let client: AirtableFetching

    private let grdbCache: ArtikelKatalogGRDBCache?
    private let jsonCache: FileBackedRepository<ArtikelItem>?

    public init(client: AirtableFetching = AirtableClient(), db: GRDBDatabase? = nil, cacheDirectory: URL? = nil) {
        self.client = client
        if let db {
            self.grdbCache = ArtikelKatalogGRDBCache(db: db)
            self.jsonCache = nil
        } else {
            self.grdbCache = nil
            self.jsonCache = try? FileBackedRepository<ArtikelItem>(filename: "artikel_katalog_cache", directory: cacheDirectory ?? DatenRoot.root())
        }
    }

    private func cacheLoadAll() -> [ArtikelItem]? {
        if let grdbCache { return try? grdbCache.alle() }
        return try? jsonCache?.loadAll()
    }

    private func cacheSaveAll(_ items: [ArtikelItem]) async {
        if let grdbCache {
            try? await Task.detached { try grdbCache.ersetzeAlle(items) }.value
        } else if let jsonCache {
            try? await Task.detached { try jsonCache.saveAll(items) }.value
        }
    }

    public func load() async {
        switch state {
        case .content: return
        case .loading: return
        default: break
        }
        if let cached = cacheLoadAll(), !cached.isEmpty {
            setContent(cached)
            await _fetchAll(showLoadingState: false)
        } else {
            state = .loading(0)
            await _fetchAll(showLoadingState: true)
        }
    }

    public func reload() async {
        state = .loading(0)
        await _fetchAll(showLoadingState: true, forceFull: true)
    }

    public func aktualisierePreis(
        artikel: ArtikelItem, korrektur: ArtikelPreisKorrektur, port: ArtikelPreisPort = ArtikelPreisPort()
    ) async -> ArtikelPreisErgebnis {
        let result = await port.schreibeKorrektur(artikel: artikel, korrektur: korrektur)
        if case .geschrieben(let newState) = result {
            if case .content(var items) = state, let index = items.firstIndex(where: { $0.id == newState.id }) {
                items[index] = newState
                setContent(items)

                if let grdbCache {
                    try? await Task.detached { try grdbCache.upsert([newState]) }.value
                } else if let jsonCache {
                    try? await Task.detached { try jsonCache.saveAll(items) }.value
                }
            }
        }
        return result
    }

    public struct AreaEntry<Wert: Comparable & Sendable>: Sendable, Equatable where Wert: Equatable {
        public var von: Wert?
        public var bis: Wert?
        public init(von: Wert? = nil, bis: Wert? = nil) {
            self.von = von
            self.bis = bis
        }
        var isEmpty: Bool { von == nil && bis == nil }

        func enthaelt(_ value: Wert?) -> Bool {
            if isEmpty { return true }
            guard let value else { return false }
            if let von, value < von { return false }
            if let bis, value > bis { return false }
            return true
        }
    }

    public struct BereichsKriterien: Sendable, Equatable {
        public var widthMm = AreaEntry<Int>()
        public var heightMm = AreaEntry<Int>()
        public var tiefeMm = AreaEntry<Int>()
        public var preisVkEuro = AreaEntry<Double>()

        public init(widthMm: AreaEntry<Int> = .init(), heightMm: AreaEntry<Int> = .init(),
                    tiefeMm: AreaEntry<Int> = .init(), preisVkEuro: AreaEntry<Double> = .init()) {
            self.widthMm = widthMm
            self.heightMm = heightMm
            self.tiefeMm = tiefeMm
            self.preisVkEuro = preisVkEuro
        }

        public var isActive: Bool {
            !widthMm.isEmpty || !heightMm.isEmpty || !tiefeMm.isEmpty || !preisVkEuro.isEmpty
        }
    }

    public nonisolated static func verenge(
        results: [ArtikelSuchergebnis], kriterien: BereichsKriterien
    ) -> [ArtikelSuchergebnis] {
        guard kriterien.isActive else { return results }
        return results.filter { entry in
            kriterien.widthMm.enthaelt(entry.artikel.widthMm)
                && kriterien.heightMm.enthaelt(entry.artikel.heightMm)
                && kriterien.tiefeMm.enthaelt(entry.artikel.tiefeMm)
                && kriterien.preisVkEuro.enthaelt(entry.artikel.vkNetto)
        }
    }

    private func setContent(_ items: [ArtikelItem]) {
        state = .content(items)
        searchIndex = ArticleSearchIndex(articles: items, vocabulary: vocabulary)
    }

    public func search(term: String) -> [ArtikelSuchergebnis] {
        let trimmed = term.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return alleArtikel.map { ArtikelSuchergebnis(artikel: $0, score: 0) }
        }
        if searchIndex == nil, alleArtikel.isEmpty == false {
            searchIndex = ArticleSearchIndex(articles: alleArtikel, vocabulary: vocabulary)
        }
        guard let searchIndex else { return [] }
        return searchIndex.search(trimmed)
    }

    public func artikel(inSupergroup supergroup: String) -> [ArtikelItem] {
        let key = SearchVocabulary.normalize(supergroup)
        return alleArtikel.filter { vocabulary.supergroup(forCategory: $0.kategorie) == key }
    }

    public nonisolated static func filtere(
        artikel: [ArtikelItem],
        term: String
    ) -> [ArtikelSuchergebnis] {
        let suchTokens = ArtikelItem.tokenize(term)
        guard !suchTokens.isEmpty else {
            return artikel.map { ArtikelSuchergebnis(artikel: $0, score: 0) }
        }
        let suchSet = Set(suchTokens)

        var results: [ArtikelSuchergebnis] = []
        for a in artikel {
            let artikelSet = Set(a.suchTokens)
            let exakt = artikelSet.intersection(suchSet).count
            var praefixTreffer = 0
            if exakt < suchSet.count {
                let restSuchTokens = suchSet.subtracting(artikelSet)
                for suchWort in restSuchTokens where artikelSet.contains(where: { $0.hasPrefix(suchWort) }) {
                    praefixTreffer += 1
                }
            }
            let score = exakt * 2 + praefixTreffer
            if score > 0 {
                results.append(ArtikelSuchergebnis(artikel: a, score: score))
            }
        }

        return results.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.artikel.articleNumber < $1.artikel.articleNumber
        }
    }

    public nonisolated static func filtereNachKategorie(
        artikel: [ArtikelItem],
        kategorie: String
    ) -> [ArtikelItem] {
        let lowerKat = kategorie.lowercased()
        return artikel.filter {
            $0.kategorie?.lowercased() == lowerKat
        }
    }

    public nonisolated static func filtereNachHersteller(
        artikel: [ArtikelItem],
        hersteller: String
    ) -> [ArtikelItem] {
        let lower = hersteller.lowercased()
        return artikel.filter {
            $0.hersteller?.lowercased() == lower
        }
    }

    private static let iso: ISO8601DateFormatter = ISO8601DateFormatter()

    private static let vollSyncNachTagen: Double = 7

    private func deltaFilterFormel() -> String? {
        guard let grdbCache,
              let zuletzt = try? grdbCache.zuletztGesynctISO(),
              let count = try? grdbCache.count(), count > 0 else { return nil }
        if let letztesDatum = Self.iso.date(from: zuletzt),
           Date().timeIntervalSince(letztesDatum) > Self.vollSyncNachTagen * 24 * 3600 {
            return nil
        }
        let escaped = zuletzt.replacingOccurrences(of: "'", with: "\\'")
        return "IS_AFTER(LAST_MODIFIED_TIME(), '\(escaped)')"
    }

    private func _fetchAll(showLoadingState: Bool, forceFull: Bool = false) async {
        let syncStart = Self.iso.string(from: Date())
        let deltaFilter: String? = forceFull ? nil : deltaFilterFormel()
        do {
            async let herstellerRecs = client.fetchRecords(baseID: Self.baseIDNeu, table: Self.herstellerTableNeu)
            async let kategorieRecs  = client.fetchRecords(baseID: Self.baseIDNeu, table: Self.kategorieTableNeu)
            async let artikelRecs    = client.fetchRecords(baseID: Self.baseIDNeu, table: Self.tableIDNeu, filterByFormula: deltaFilter)
            let herstellerByID = Self.nameByRecordID(try await herstellerRecs)
            let kategorieRecords = try await kategorieRecs
            let kategorieByID  = Self.nameByRecordID(kategorieRecords)
            vocabulary = Self.mapVocabulary(from: kategorieRecords)
            let records = try await artikelRecs
            if showLoadingState { state = .loading(records.count) }

            let mapped = await Task.detached(priority: .userInitiated) {
                Self.mapArtikelItemsNeu(from: records, herstellerByID: herstellerByID, kategorieByID: kategorieByID)
            }.value

            if let grdbCache, deltaFilter != nil {
                try? await Task.detached { try grdbCache.upsert(mapped) }.value
                try? grdbCache.setzeZuletztGesynct(syncStart)
                let alle = await Task.detached { (try? grdbCache.alle()) ?? [] }.value
                if alle.isEmpty == false { setContent(alle) }
                return
            }

            if mapped.isEmpty {
                if showLoadingState {
                    state = records.isEmpty ? .empty : .error("Keine Artikel mit Artikelnummer-Feld gemappt (\(records.count) Rohdaten). Feld-Namen prüfen.")
                }
            } else {
                setContent(mapped)
                await cacheSaveAll(mapped)
                try? grdbCache?.setzeZuletztGesynct(syncStart)
            }
        } catch AirtableError.notConnected {
            if showLoadingState { state = .notConnected }
        } catch AirtableError.httpError(let code) {
            if showLoadingState { state = .error("HTTP \(code) — Airtable nicht erreichbar oder Base-ID falsch.") }
        } catch AirtableError.decodingFailed {
            if showLoadingState { state = .error("Antwort konnte nicht dekodiert werden — API-Format geändert?") }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    public nonisolated static func mapArtikelItems(
        from records: [[String: AirtableFieldValue]]
    ) -> [ArtikelItem] {
        records.compactMap { fields in

            guard let articleNumber = fields[feldArtikelnummer]?.anyStringValue,
                  !articleNumber.trimmingCharacters(in: .whitespaces).isEmpty else {
                return nil
            }
            let recordID = fields["_airtableRecordID"]?.stringValue ?? articleNumber

            let imageUrl = fields[feldProduktbild]?.firstArrayValue ?? fields[feldProduktbild]?.stringValue
            return ArtikelItem(
                id: recordID,
                articleNumber: articleNumber,
                hersteller: fields[feldHersteller]?.anyStringValue,
                kategorie: fields[feldKategorie]?.anyStringValue,
                artikelbeschreibung: fields[feldBeschreibung]?.anyStringValue,
                ean: fields[feldEAN]?.anyStringValue,
                ekNetto: fields[feldEKNetto]?.numberValue,
                vkNetto: fields[feldVKNetto]?.numberValue,
                produktbildURL: imageUrl
            )
        }
    }

    public nonisolated static func mapArtikelItemsNeu(
        from records: [[String: AirtableFieldValue]],
        herstellerByID: [String: String] = [:],
        kategorieByID: [String: String] = [:]
    ) -> [ArtikelItem] {
        records.compactMap { fields in
            guard let articleNumber = fields[feldNeuArtikelnummer]?.anyStringValue,
                  articleNumber.trimmingCharacters(in: .whitespaces).isEmpty == false else {
                return nil
            }
            let recordID = fields["_airtableRecordID"]?.stringValue ?? articleNumber
            let herstellerID = fields[feldNeuHersteller]?.firstArrayValue
            let kategorieID  = fields[feldNeuKategorie]?.firstArrayValue
            return ArtikelItem(
                id: recordID,
                articleNumber: articleNumber,
                hersteller: herstellerID.flatMap { herstellerByID[$0] },
                kategorie: kategorieID.flatMap { kategorieByID[$0] },
                artikelbeschreibung: fields[feldNeuBezeichnung]?.anyStringValue
                    ?? fields[feldNeuBeschreibung]?.anyStringValue,
                detailText: Self.detailText(from: fields),
                ean: fields[feldNeuEAN]?.anyStringValue,
                ekNetto: fields[feldNeuEKNetto]?.numberValue,
                vkNetto: fields[feldNeuVKNetto]?.numberValue,
                produktbildURL: fields[feldNeuBildURL]?.anyStringValue,

                reviewZustand: ArtikelReviewMapper.status(aus: fields),

                sevDeskArtikelID: fields[feldNeuSevDeskArtikelID]?.anyStringValue,

                widthMm: fields[feldNeuBreiteMm]?.numberValue.map { Int($0.rounded()) },
                heightMm: fields[feldNeuHoeheMm]?.numberValue.map { Int($0.rounded()) },
                tiefeMm: fields[feldNeuTiefeMm]?.numberValue.map { Int($0.rounded()) },
                gewichtGramm: fields[feldNeuGewichtG]?.numberValue.map { Int($0.rounded()) }
            )
        }
    }

    nonisolated static func detailText(from fields: [String: AirtableFieldValue]) -> String? {
        let title = fields[feldNeuBezeichnung]?.anyStringValue
        let description = fields[feldNeuBeschreibung]?.anyStringValue
        var parts: [String] = []
        if let description, description.isEmpty == false, description != title {
            parts.append(description)
        }
        if let variant = fields[feldNeuVariante]?.anyStringValue, variant.isEmpty == false {
            parts.append(variant)
        }
        if let measurements = fields[feldNeuMasse]?.anyStringValue, measurements.isEmpty == false {
            parts.append(measurements)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    nonisolated static func mapVocabulary(
        from records: [[String: AirtableFieldValue]]
    ) -> SearchVocabulary {
        let entries: [SearchVocabulary.CategoryEntry] = records.compactMap { fields in
            guard let name = fields[feldKategorieName]?.anyStringValue,
                  name.trimmingCharacters(in: .whitespaces).isEmpty == false else { return nil }
            let synonyms = (fields[feldSynonyme]?.anyStringValue ?? "")
                .components(separatedBy: CharacterSet(charactersIn: "\n,;"))
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.isEmpty == false }
            return SearchVocabulary.CategoryEntry(
                name: name,
                supergroup: fields[feldOberkategorie]?.anyStringValue,
                synonyms: synonyms)
        }
        return SearchVocabulary(categories: entries)
    }

    nonisolated static func nameByRecordID(_ records: [[String: AirtableFieldValue]]) -> [String: String] {
        var map: [String: String] = [:]
        for fields in records {
            guard let id = fields["_airtableRecordID"]?.stringValue,
                  let name = fields["Name"]?.anyStringValue,
                  name.isEmpty == false else { continue }
            map[id] = name
        }
        return map
    }

    public func ladeAusKandidatenBase() async throws -> [ArtikelItem] {
        async let herstellerRecs = client.fetchRecords(baseID: Self.baseIDNeu, table: Self.herstellerTableNeu)
        async let kategorieRecs  = client.fetchRecords(baseID: Self.baseIDNeu, table: Self.kategorieTableNeu)
        async let artikelRecs    = client.fetchRecords(baseID: Self.baseIDNeu, table: Self.tableIDNeu)
        let herstellerByID = Self.nameByRecordID(try await herstellerRecs)
        let kategorieByID  = Self.nameByRecordID(try await kategorieRecs)
        return Self.mapArtikelItemsNeu(
            from: try await artikelRecs, herstellerByID: herstellerByID, kategorieByID: kategorieByID)
    }
}

extension ArtikelKatalogStore: ArticlePriceLookup {
    public func purchaseNet(matching term: String) async -> Double? {
        search(term: term).first?.artikel.ekNetto
    }
}
