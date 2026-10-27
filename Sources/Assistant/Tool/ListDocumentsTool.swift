public struct ListDocumentsTool: ToolPort {
    private let receipts: any ReceiptPort

    public init(receipts: any ReceiptPort) {
        self.receipts = receipts
    }

    public var name: String { "list_belege" }
    public var access: ToolAccess { .read }
    public var privacy: PrivacyCategory { .drive }
    public var documented: Bool { false }
    public var parameters: [ToolParameter] { [ToolParameter("projekt")] }

    public func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let query = input.text("projekt").lowercased()
        let all = await receipts.receipts()
        let match = query.isEmpty ? all : all.filter {
            $0.projectNumber.lowercased().contains(query)
                || $0.number.lowercased().contains(query)
                || ($0.customerName?.lowercased().contains(query) ?? false)
        }
        guard match.isEmpty == false else {
            return ToolResult(query.isEmpty ? .make("assistant.receipts.none") : .make("assistant.receipts.noMatch", query))
        }
        let rows: [Phrase] = match.sorted { $0.createdAt > $1.createdAt }.prefix(ListingEngine.rowLimit).map { entry in
            var text = "\u{2022} \(entry.kind) \(entry.number) | \(entry.projectNumber)"
            if let customer = entry.customerName, customer.isEmpty == false { text += " | \(customer)" }
            return .raw(text + " | \(ListingEngine.day(entry.createdAt))")
        }
        return ToolResult(lines: ListingEngine.clip(rows, total: match.count))
    }
}
