public struct ProposeCartItemTool: ToolPort {
    static let matchLimit = 5

    private let catalog: (any CatalogPort)?
    private let stock: (any StockPort)?

    public init(catalog: (any CatalogPort)?, stock: (any StockPort)?) {
        self.catalog = catalog
        self.stock = stock
    }

    public var name: String { "propose_warenkorb" }
    public var access: ToolAccess { .propose }
    public var privacy: PrivacyCategory { .catalogCalculation }
    public var documented: Bool { false }
    public var parameters: [ToolParameter] { [ToolParameter("artikel", required: true), ToolParameter("menge", kind: .integer)] }

    private enum Found {
        case one(CartDraft, label: String)
        case ambiguous([String])
        case none
    }

    public func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let search = input.text("artikel")
        guard search.isEmpty == false else { return .failure("assistant.cart.noArticle") }
        let quantity = max(input.integer("menge") ?? 1, 1)
        switch await find(search, quantity: quantity) {
        case .none:
            return .failure("assistant.cart.noMatch", search)
        case .ambiguous(let names):
            return .failure("assistant.cart.ambiguous", search, names.joined(separator: " \u{00B7} "))
        case .one(let draft, let label):
            let key = draft.source == .catalog ? "assistant.cart.readyCatalog" : "assistant.cart.readyStock"
            return ToolResult(.make(key, String(quantity), label), cards: [.cartDraft(draft)])
        }
    }

    private func find(_ search: String, quantity: Int) async -> Found {
        if let catalog, case .matches(let articles) = await catalog.search(term: search, limit: Self.matchLimit) {
            let match = Array(articles.prefix(Self.matchLimit))
            if match.count == 1, let article = match.first {
                let draft = CartDraft(label: article.label, articleNumber: article.articleNumber, quantity: quantity,
                                      purchaseNet: article.purchaseNet, saleNet: article.saleNet, source: .catalog,
                                      recordID: article.id)
                return .one(draft, label: article.label)
            }
            if match.count > 1 { return .ambiguous(match.map(\.label)) }
        }
        if let stock, case .items(let items) = await stock.current() {
            let match = items.filter {
                $0.label.localizedCaseInsensitiveContains(search)
                    || ($0.articleNumber?.localizedCaseInsensitiveContains(search) ?? false)
            }.prefix(Self.matchLimit)
            if match.count == 1, let item = match.first {
                let draft = CartDraft(label: item.label, articleNumber: item.articleNumber ?? item.id, quantity: quantity,
                                      purchaseNet: item.purchaseNet, saleNet: item.saleNet, source: .stock, recordID: item.id)
                return .one(draft, label: item.label)
            }
            if match.count > 1 { return .ambiguous(match.map(\.label)) }
        }
        return .none
    }
}
