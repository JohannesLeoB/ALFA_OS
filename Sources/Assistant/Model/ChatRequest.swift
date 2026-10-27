public struct ChatRequest: Sendable {
    var messages: [Message]
    var system: String
    var tools: [ToolDefinition]
    var maxTokens: Int
    var model: String?

    init(messages: [Message], system: String, tools: [ToolDefinition] = [], maxTokens: Int, model: String? = nil) {
        self.messages = messages
        self.system = system
        self.tools = tools
        self.maxTokens = maxTokens
        self.model = model
    }
}
