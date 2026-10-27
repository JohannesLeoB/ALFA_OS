import Assistant
import Calculation
import Core
import Hub

public actor ArticleStore: CatalogPort, ArticlePricePort {
    private let fetch: any RecordFetchPort
    private let baseID: String
    private let articleTable: String
    private let manufacturerTable: String
    private let categoryTable: String
    private let saleField: String
    private var entries: [CatalogEntry]?
    private var loading: Task<[CatalogEntry], any Error>?

    public init(fetch: any RecordFetchPort,
                baseID: String = CompanyValues.valueOrEmpty("airtable.base.article_catalog"),
                articleTable: String = CompanyValues.valueOrEmpty("airtable.table.article_catalog"),
                manufacturerTable: String = CompanyValues.valueOrEmpty("airtable.table.manufacturers_new"),
                categoryTable: String = CompanyValues.valueOrEmpty("airtable.table.categories_new"),
                saleField: String = CompanyValues.valueOrEmpty("airtable.field.sale_price")) {
        self.fetch = fetch
        self.baseID = baseID
        self.articleTable = articleTable
        self.manufacturerTable = manufacturerTable
        self.categoryTable = categoryTable
        self.saleField = saleField
    }

    public func search(term: String, limit: Int) async -> ArticleSearchState {
        do {
            let loaded = try await load()
            guard loaded.isEmpty == false else { return .empty }
            let hits = ArticleEngine.search(loaded, term: term).prefix(max(limit, 0))
            return .matches(hits.map(ArticleEngine.article))
        } catch AirtableFailure.notConnected {
            return .notConnected
        } catch let failure as AirtableFailure {
            return .failed(failure.detail)
        } catch {
            return .failed(String(describing: error))
        }
    }

    public func purchaseNet(matching term: String) async -> Double? {
        guard let loaded = try? await load() else { return nil }
        return ArticleEngine.search(loaded, term: term).first?.purchaseNet
    }

    func reload() {
        entries = nil
    }

    private func load() async throws -> [CatalogEntry] {
        if let entries { return entries }
        if let loading { return try await loading.value }
        let task = Task { [fetch, baseID, articleTable, manufacturerTable, categoryTable, saleField] in
            try await Self.fetchAll(fetch, baseID, articleTable, manufacturerTable, categoryTable, saleField)
        }
        loading = task
        defer { loading = nil }
        let loaded = try await task.value
        entries = loaded
        return loaded
    }

    private static func fetchAll(_ fetch: any RecordFetchPort, _ baseID: String, _ articleTable: String,
                                 _ manufacturerTable: String, _ categoryTable: String, _ saleField: String) async throws -> [CatalogEntry] {
        async let manufacturers = fetch.fetchRecords(baseID: baseID, table: manufacturerTable)
        async let categories = fetch.fetchRecords(baseID: baseID, table: categoryTable)
        async let articles = fetch.fetchRecords(baseID: baseID, table: articleTable)
        let manufacturerNames = ArticleEngine.names(of: try await manufacturers)
        let categoryNames = ArticleEngine.names(of: try await categories)
        let records = try await articles
        let mapped = try ArticleEngine.entries(from: records, manufacturers: manufacturerNames, categories: categoryNames,
                                               saleField: saleField)
        if mapped.isEmpty, records.isEmpty == false { throw AirtableFailure.unmapped(records.count) }
        return mapped
    }
}
