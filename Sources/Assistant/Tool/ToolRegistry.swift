import Foundation

public struct ToolRegistry: Sendable {
    let tools: [any ToolPort]

    public init(tools: [any ToolPort]) {
        self.tools = tools
    }

    var categories: Set<PrivacyCategory> { Set(tools.map(\.privacy)) }

    var manifest: ToolManifest { ToolManifest(tools: tools) }

    func tool(named name: String) -> (any ToolPort)? {
        tools.first { $0.name == name }
    }

    func run(name: String, inputJSON: Data, scope: ToolScope, allowed: Set<String>) async -> ToolResult {
        guard allowed.contains(name), let tool = tool(named: name) else {
            return .failure("assistant.engine.toolNotAllowed", name)
        }
        return await tool.run(ToolInput(json: inputJSON), scope: scope)
    }
}
