enum WireBlock: Encodable, Equatable {
    case text(String)
    case toolUse(id: String, name: String, input: JSONValue)
    case toolResult(toolUseID: String, content: String, isError: Bool)
    case image(mediaType: String, base64: String)
    case document(mediaType: String, base64: String, title: String)
    case textDocument(text: String, title: String)

    enum CodingKeys: String, CodingKey {
        case type, text, id, name, input
        case toolUseID = "tool_use_id", content, isError = "is_error"
        case source, title
    }

    enum SourceKeys: String, CodingKey {
        case type, mediaType = "media_type", data
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .toolUse(let id, let name, let input):
            try container.encode("tool_use", forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(input, forKey: .input)
        case .toolResult(let toolUseID, let content, let isError):
            try container.encode("tool_result", forKey: .type)
            try container.encode(toolUseID, forKey: .toolUseID)
            try container.encode(content, forKey: .content)
            try container.encode(isError, forKey: .isError)
        case .image(let mediaType, let base64):
            try container.encode("image", forKey: .type)
            var source = container.nestedContainer(keyedBy: SourceKeys.self, forKey: .source)
            try source.encode("base64", forKey: .type)
            try source.encode(mediaType, forKey: .mediaType)
            try source.encode(base64, forKey: .data)
        case .document(let mediaType, let base64, let title):
            try container.encode("document", forKey: .type)
            try container.encode(title, forKey: .title)
            var source = container.nestedContainer(keyedBy: SourceKeys.self, forKey: .source)
            try source.encode("base64", forKey: .type)
            try source.encode(mediaType, forKey: .mediaType)
            try source.encode(base64, forKey: .data)
        case .textDocument(let text, let title):
            try container.encode("document", forKey: .type)
            try container.encode(title, forKey: .title)
            var source = container.nestedContainer(keyedBy: SourceKeys.self, forKey: .source)
            try source.encode("text", forKey: .type)
            try source.encode("text/plain", forKey: .mediaType)
            try source.encode(text, forKey: .data)
        }
    }
}

struct WireMessage: Encodable, Equatable {
    var role: String
    var content: [WireBlock]
}

struct SystemBlock: Encodable, Equatable {
    let type = "text"
    let text: String
    var cacheControl: CacheControl?

    enum CodingKeys: String, CodingKey { case type, text, cacheControl = "cache_control" }
}

struct WirePayload: Encodable {
    var model: String
    var maxTokens: Int
    var system: [SystemBlock]
    var messages: [WireMessage]
    var tools: [ToolDefinition]?
    var stream: Bool?

    enum CodingKeys: String, CodingKey {
        case model, maxTokens = "max_tokens", system, messages, tools, stream
    }
}
