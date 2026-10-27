struct ListProjectsTool: ToolPort {
    private let projects: ProjectSearchEngine

    init(projects: ProjectSearchEngine) {
        self.projects = projects
    }

    var name: String { "list_projects" }
    var access: ToolAccess { .read }
    var privacy: PrivacyCategory { .studioKnowledge }
    var documented: Bool { false }
    var parameters: [ToolParameter] { [ToolParameter("suche")] }

    func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let query = input.text("suche").lowercased()
        let match = projects.filter(query)
        guard match.isEmpty == false else {
            return ToolResult(query.isEmpty ? .make("assistant.projects.none") : .make("assistant.projects.noMatch", query))
        }
        let rows: [Phrase] = match.prefix(ListingEngine.rowLimit).map { entry in
            var parts: [Phrase] = [.raw("\u{2022} \(entry.projectNumber) | \(entry.title)")]
            if let customer = entry.customerName, customer.isEmpty == false { parts.append(.raw(" | \(customer)")) }
            if let phase = entry.phase, phase.isEmpty == false { parts.append(.make("assistant.projects.phase", phase)) }
            if let budget = ListingEngine.money(entry.budget) { parts.append(.make("assistant.projects.budget", budget)) }
            return .join(parts, "")
        }
        return ToolResult(lines: ListingEngine.clip(rows, total: match.count))
    }
}
