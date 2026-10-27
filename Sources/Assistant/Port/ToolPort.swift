public protocol ToolPort: Sendable {
    var name: String { get }
    var access: ToolAccess { get }
    var privacy: PrivacyCategory { get }
    var parameters: [ToolParameter] { get }
    var manifestID: String { get }
    var activityKey: String { get }
    var documented: Bool { get }
    var focusNeed: FocusNeed { get }
    func promptKeys(available: Set<String>) -> [String]
    func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult
}

public extension ToolPort {
    var manifestID: String { ToolManifest.umbrellaID }
    var activityKey: String { "assistant.activity." + name }
    var documented: Bool { true }
    var focusNeed: FocusNeed { .none }

    func promptKeys(available: Set<String>) -> [String] { [promptKey] }
    var descriptionKey: String { "assistant.tool." + name + ".description" }
    var promptKey: String { "assistant.tool." + name + ".prompt" }

    func parameterKey(_ parameter: String) -> String {
        "assistant.tool." + name + ".param." + parameter
    }
}
