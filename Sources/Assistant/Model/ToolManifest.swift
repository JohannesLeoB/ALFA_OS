struct ToolManifest: Sendable, Equatable {
    static let version = 2
    static let umbrellaID = "ASSISTANT_TOOL_CALL"

    private let identifiers: [String: String]

    init(tools: [any ToolPort]) {
        var identifiers: [String: String] = [:]
        for tool in tools { identifiers[tool.name] = tool.manifestID }
        self.identifiers = identifiers
    }

    func identifier(forTool name: String) -> String {
        identifiers[name] ?? Self.umbrellaID
    }
}
