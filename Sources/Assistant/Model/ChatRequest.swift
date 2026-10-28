public struct ChatRequest: Sendable {
    var messages: [Message]
    var system: String
    var tools: [ToolDefinition]
    var maxTokens: Int
    var model: String?
    var sharesFiles: Bool

    init(messages: [Message], system: String, tools: [ToolDefinition] = [], maxTokens: Int, model: String? = nil,
         sharesFiles: Bool = false) {
        self.messages = messages
        self.system = system
        self.tools = tools
        self.maxTokens = maxTokens
        self.model = model
        self.sharesFiles = sharesFiles
    }
}
