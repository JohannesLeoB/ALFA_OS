public struct SearchCatalogTool: ToolPort {
    static let wireName = "search_katalog"
    static let hitLimit = 10

    private let catalog: any CatalogPort

    public init(catalog: any CatalogPort) {
        self.catalog = catalog
    }

    public var name: String { Self.wireName }
    public var access: ToolAccess { .read }
    public var privacy: PrivacyCategory { .catalogCalculation }
    public var manifestID: String { "AIRTABLE_ARTIKELKATALOG" }
    public var parameters: [ToolParameter] { [ToolParameter("query", required: true)] }

    public func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let query = input.text("query")
        guard query.isEmpty == false else { return .failure("assistant.catalog.emptyQuery") }
        switch await catalog.search(term: query, limit: Self.hitLimit) {
        case .notConnected:
            return .failure("assistant.catalog.notConnected")
        case .failed(let message):
            return .failure("assistant.catalog.failed", message)
        case .empty:
            return .failure("assistant.catalog.empty")
        case .loading(let count):
            return ToolResult(count > 0 ? .make("assistant.catalog.loadingCount", String(count)) : .make("assistant.catalog.loading"))
        case .matches(let articles):
            guard articles.isEmpty == false else { return ToolResult(.make("assistant.catalog.noHits", query)) }
            var lines: [Phrase] = [.make("assistant.catalog.header", query)]
            lines += articles.map { Self.row($0) }
            return ToolResult(lines: lines)
        }
    }

    static func row(_ article: Article) -> Phrase {
        var parts: [Phrase] = [
            .raw("\u{2022} \(article.manufacturer ?? "\u{2013}") | \(article.label)"),
            .make("assistant.catalog.article", article.articleNumber),
        ]
        if let sale = ListingEngine.money(article.saleNet) { parts.append(.make("assistant.catalog.sale", sale)) }
        if let purchase = ListingEngine.money(article.purchaseNet) { parts.append(.make("assistant.catalog.purchase", purchase)) }
        return .join(parts, "")
    }
}
