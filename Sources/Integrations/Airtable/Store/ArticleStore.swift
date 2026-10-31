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

public actor StockStore: StockPort {
    static let tableName = "Lagerliste"

    private let loader: RecordListStore<StockItem>
    private var items: [StockItem] = []

    public init(fetch: any RecordFetchPort,
                baseID: String = CompanyValues.valueOrEmpty("airtable.base.article_catalog"),
                table: String? = nil) {
        loader = RecordListStore(fetch: fetch, baseID: baseID, table: table ?? Self.tableName, map: StockEngine.items(from:))
    }

    public func current() async -> StockListState {
        if items.isEmpty == false { return .items(items) }
        do {
            let loaded = try await loader.load()
            guard loaded.isEmpty == false else { return .empty }
            items = loaded
            return .items(loaded)
        } catch AirtableFailure.notConnected {
            return .notConnected
        } catch let failure as AirtableFailure {
            return .failed(failure.detail)
        } catch {
            return .failed(String(describing: error))
        }
    }

    func reload() {
        items = []
    }
}

struct RecordListStore<Item: Sendable>: Sendable {
    let fetch: any RecordFetchPort
    let baseID: String
    let table: String
    let map: @Sendable ([Record]) -> [Item]

    func load() async throws -> [Item] {
        map(try await fetch.fetchRecords(baseID: baseID, table: table))
    }
}

public struct AnchorRowStore: AnchorRowsPort {
    static let tableName = "Preisanker"

    private let fetch: any RecordFetchPort
    private let baseID: String
    private let table: String

    public init(fetch: any RecordFetchPort,
                baseID: String = CompanyValues.valueOrEmpty("airtable.base.estimation_model"),
                table: String? = nil) {
        self.fetch = fetch
        self.baseID = baseID
        self.table = table ?? Self.tableName
    }

    public func fetchAnchorRows() async throws -> [[String: String]] {
        try await fetch.fetchRecords(baseID: baseID, table: table).map { record in
            record.fields.mapValues { $0.anyStringValue ?? $0.firstArrayValue ?? "" }
        }
    }
}

public struct CustomerContactStore: ContactFeedPort {
    private let fetch: any RecordFetchPort
    private let baseID: String
    private let table: String
    private let nameField: String
    private let addressField: String

    public init(fetch: any RecordFetchPort,
                baseID: String = CompanyValues.valueOrEmpty("airtable.base.golden_customers"),
                table: String = CompanyValues.valueOrEmpty("airtable.table.golden_customers"),
                nameField: String = CompanyValues.valueOrEmpty("airtable.field.customer_name"),
                addressField: String = CompanyValues.valueOrEmpty("airtable.field.customer_email")) {
        self.fetch = fetch
        self.baseID = baseID
        self.table = table
        self.nameField = nameField
        self.addressField = addressField
    }

    public var configured: Bool { ![baseID, table, addressField].contains(where: \.isEmpty) }

    public func people() async throws -> [ContactPerson] {
        guard configured else { return [] }
        return try await fetch.fetchRecords(baseID: baseID, table: table).compactMap { record in
            guard let address = record.fields[addressField]?.anyStringValue, !address.isEmpty else { return nil }
            return ContactPerson(name: record.fields[nameField]?.anyStringValue ?? "", address: address)
        }
    }
}

public struct EstimationParameterStore: CarcassParameterPort {
    static let tableName = "Sch\u{00E4}tzmodell"
    static let keyField = "Schl\u{00FC}ssel"
    static let valueField = "Wert"

    private let fetch: any RecordFetchPort
    private let baseID: String
    private let table: String

    public init(fetch: any RecordFetchPort,
                baseID: String = CompanyValues.valueOrEmpty("airtable.base.estimation_model"),
                table: String? = nil) {
        self.fetch = fetch
        self.baseID = baseID
        self.table = table ?? Self.tableName
    }

    public func load() async throws -> CarcassParameters? {
        let records = try await fetch.fetchRecords(baseID: baseID, table: table)
        var values: [String: Double] = [:]
        for record in records {
            guard let key = record.fields[Self.keyField]?.anyStringValue, key.isEmpty == false,
                  let value = Self.number(record.fields[Self.valueField]) else { continue }
            values[key] = value
        }
        guard values.isEmpty == false else { return nil }
        return CarcassParameters.from(parameters: values, fallback: .seed())
    }

    public func parameters() async -> CarcassParameters? {
        (try? await load()) ?? nil
    }

    static func number(_ value: FieldValue?) -> Double? {
        guard let value else { return nil }
        if let number = value.numberValue { return number }
        if let text = value.anyStringValue { return Double(text.replacingOccurrences(of: ",", with: ".")) }
        return nil
    }
}

public struct CredentialsStore: CredentialsPort {
    static let tokenName = "token"
    static let baseName = "base"

    private let keychain: any KeychainPort
    private let inlet: Inlet.ID

    public init(keychain: any KeychainPort, inlet: Inlet.ID) {
        self.keychain = keychain
        self.inlet = inlet
    }

    public func load() throws -> Credentials? {
        guard let token = try keychain.get(KeySlot(inlet: inlet, name: Self.tokenName)), token.isEmpty == false else {
            return nil
        }
        let base = try keychain.get(KeySlot(inlet: inlet, name: Self.baseName)) ?? ""
        return Credentials(token: token, baseID: base)
    }
}

public struct Credentials: Equatable, Sendable {
    public var token: String
    var baseID: String

    public init(token: String, baseID: String) {
        self.token = token
        self.baseID = baseID
    }
}
