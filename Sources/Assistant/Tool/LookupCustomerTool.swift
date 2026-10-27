struct LookupCustomerTool: ToolPort {
    static let overviewWords: Set<String> = ["\u{FC}bersicht", "overview", "alle", "liste"]

    private let customers: CustomerSearchEngine

    init(customers: CustomerSearchEngine) {
        self.customers = customers
    }

    var name: String { "lookup_kunde" }
    var access: ToolAccess { .read }
    var privacy: PrivacyCategory { .contacts }
    var manifestID: String { "AIRTABLE_KUNDEN_LOOKUP" }
    var documented: Bool { false }
    var parameters: [ToolParameter] { [ToolParameter("query")] }

    func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let query = input.text("query")
        if query.isEmpty || Self.overviewWords.contains(query.lowercased()) {
            return ToolResult(lines: customers.overview())
        }
        let hits = customers.lookup(query)
        guard hits.isEmpty == false else { return ToolResult(.make("assistant.customers.noHits", query)) }
        return ToolResult(lines: hits.map(customers.describe))
    }
}
