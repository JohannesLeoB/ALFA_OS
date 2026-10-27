public struct ListStockTool: ToolPort {
    private let stock: any StockPort

    public init(stock: any StockPort) {
        self.stock = stock
    }

    public var name: String { "list_lager" }
    public var access: ToolAccess { .read }
    public var privacy: PrivacyCategory { .catalogCalculation }
    public var documented: Bool { false }
    public var parameters: [ToolParameter] { [ToolParameter("suche")] }

    public func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let query = input.text("suche").lowercased()
        switch await stock.current() {
        case .loading:
            return ToolResult(.make("assistant.stock.loading"))
        case .notConnected:
            return .failure("assistant.stock.notConnected")
        case .failed(let message):
            return .failure("assistant.stock.failed", message)
        case .empty:
            return .failure("assistant.stock.empty")
        case .items(let items):
            let match = query.isEmpty ? items : items.filter { item in
                item.label.lowercased().contains(query)
                    || (item.manufacturer?.lowercased().contains(query) ?? false)
                    || (item.category?.lowercased().contains(query) ?? false)
                    || (item.articleNumber?.lowercased().contains(query) ?? false)
            }
            guard match.isEmpty == false else { return ToolResult(.make("assistant.stock.noMatch", query)) }
            let rows: [Phrase] = match.prefix(ListingEngine.rowLimit).map { item in
                var parts: [Phrase] = [.raw("\u{2022} \(item.label)")]
                if let manufacturer = item.manufacturer, manufacturer.isEmpty == false { parts.append(.raw(" | \(manufacturer)")) }
                if let number = item.articleNumber, number.isEmpty == false { parts.append(.make("assistant.catalog.article", number)) }
                if let quantity = item.quantity { parts.append(.make("assistant.stock.quantity", String(quantity))) }
                if let sale = ListingEngine.money(item.saleNet) { parts.append(.make("assistant.catalog.sale", sale)) }
                return .join(parts, "")
            }
            return ToolResult(lines: ListingEngine.clip(rows, total: match.count))
        }
    }
}
