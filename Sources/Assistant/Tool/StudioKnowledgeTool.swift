struct StudioKnowledgeTool: ToolPort {
    static let overviewWords: Set<String> = ["\u{FC}bersicht", "overview", "statistik", "gesamt", "stats"]

    private let knowledge: StudioKnowledge

    init(knowledge: StudioKnowledge) {
        self.knowledge = knowledge
    }

    var name: String { "query_studio_knowledge" }
    var access: ToolAccess { .read }
    var privacy: PrivacyCategory { .studioKnowledge }
    var manifestID: String { "STUDIO_KNOWLEDGE_QUERY" }
    var parameters: [ToolParameter] { [ToolParameter("query")] }

    func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let query = input.text("query")
        if query.isEmpty || Self.overviewWords.contains(query.lowercased()) {
            return ToolResult(lines: knowledge.overview())
        }
        let hits = knowledge.lookup(query)
        guard hits.isEmpty == false else { return ToolResult(.make("assistant.studio.noHits", query)) }
        return ToolResult(lines: hits.map(knowledge.describe))
    }
}
