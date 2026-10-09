import Foundation

/// One request to the Messages API.
public struct AIRequest: Sendable, Equatable {
    public var model: String
    public var system: String
    public var messages: [AIMessage]
    public var maxTokens: Int
    public var temperature: Double?
    /// The prompt cache of the platform. Automatic by default; the platform keeps the cache.
    public var cache: AICachePolicy
    /// The tools that the model may use. Empty by default; the tool choice is left to the platform.
    public var tools: [AITool]
    /// How much work the model spends on the answer. Nil leaves the platform default of the model.
    public var effort: AIEffort?
    /// How the model thinks before it answers. Nil leaves the platform default of the model.
    public var thinking: AIThinking?
    /// The shape of the answer. Nil leaves the answer as free text.
    public var format: AIOutputFormat?

    public init(
        model: String,
        system: String,
        messages: [AIMessage],
        maxTokens: Int,
        temperature: Double? = nil,
        cache: AICachePolicy = .automatic(ttl: .fiveMinutes),
        tools: [AITool] = [],
        effort: AIEffort? = nil,
        thinking: AIThinking? = nil,
        format: AIOutputFormat? = nil
    ) {
        self.model = model
        self.system = system
        self.messages = messages
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.cache = cache
        self.tools = tools
        self.effort = effort
        self.thinking = thinking
        self.format = format
    }
}

/// The effort of the model. The values are the names of the platform; a model knows only some of them.
public enum AIEffort: String, Sendable, Equatable, CaseIterable {
    case low
    case medium
    case high
    case xhigh
    case max
}

/// How the model thinks before it answers.
public enum AIThinking: Sendable, Equatable {
    /// The model decides how long it thinks.
    case adaptive
    /// Thinking is off. Only Haiku and Sonnet take it.
    case disabled
    /// Thinking before the first answer and between tool calls. Only Sonnet takes it.
    case betweenTools

    /// The name of the type in the request.
    var wireName: String {
        switch self {
        case .adaptive: "adaptive"
        case .disabled: "disabled"
        case .betweenTools: "between_tools"
        }
    }
}

/// The shape of the answer that the platform must keep.
public enum AIOutputFormat: Sendable, Equatable {
    /// The answer follows this JSON schema.
    case jsonSchema(JSONValue)
}

/// Whether the platform caches the prompt of a request.
public enum AICachePolicy: Sendable, Equatable {
    /// The platform caches the whole prompt up to the last block; the time to live is set by `ttl`.
    case automatic(ttl: AICacheTTL)
    /// No cache field is sent.
    case off
}

/// How long the platform keeps a cached prompt.
public enum AICacheTTL: Sendable, Equatable {
    /// The default of the platform; it is refreshed at no cost each time the cache is used.
    case fiveMinutes
    /// Costs more to write than the default, and lasts one hour.
    case oneHour
}

/// One turn of a conversation.
public struct AIMessage: Sendable, Equatable {
    public enum Role: String, Sendable, Equatable {
        case user
        case assistant
    }

    public var role: Role
    public var blocks: [AIBlock]

    public init(role: Role, blocks: [AIBlock]) {
        self.role = role
        self.blocks = blocks
    }
}

/// One part of a message. Blocks of an answer are kept as they came, so that they can go back unchanged.
public enum AIBlock: Sendable, Equatable {
    /// Text that the app sends.
    case text(String)
    /// An image that the app sends.
    case image(AIImage)
    /// A call of a tool by the model. The app answers it with `toolResult`.
    case toolUse(id: String, name: String, input: JSONValue)
    /// The answer of the app to a call of a tool.
    case toolResult(toolUseID: String, content: String, isError: Bool)
    /// A tool that the platform ran itself, such as the web search.
    case serverToolUse(id: String, name: String, input: JSONValue)
    /// The result of a web search. Its content goes back exactly as the platform sent it.
    case webSearchToolResult(toolUseID: String, content: JSONValue)
    /// Any other block as the platform wrote it, for example text with citations or thinking.
    case raw(JSONValue)
}

extension AIBlock {
    /// The block of an answer, read from its JSON. Only the kinds that the app acts on get their own case.
    init(wire json: JSONValue) {
        switch json["type"]?.string {
        case "tool_use"?:
            if let id = json["id"]?.string, let name = json["name"]?.string, let input = json["input"] {
                self = .toolUse(id: id, name: name, input: input)
            } else {
                self = .raw(json)
            }
        case "server_tool_use"?:
            if let id = json["id"]?.string, let name = json["name"]?.string, let input = json["input"] {
                self = .serverToolUse(id: id, name: name, input: input)
            } else {
                self = .raw(json)
            }
        case "web_search_tool_result"?:
            self = .webSearchToolResult(toolUseID: json["tool_use_id"]?.string ?? "", content: json["content"] ?? .null)
        default:
            self = .raw(json)
        }
    }
}

/// Why the platform stopped its answer.
public enum AIStopReason: Sendable, Equatable {
    case endTurn
    case maxTokens
    case toolUse
    /// The platform paused a long turn. The answer goes back unchanged, and the platform continues it.
    case pauseTurn
    case refusal
    /// A reason that this version does not know. The text is kept.
    case unknown(String)

    init(wire text: String) {
        switch text {
        case "end_turn": self = .endTurn
        case "max_tokens": self = .maxTokens
        case "tool_use": self = .toolUse
        case "pause_turn": self = .pauseTurn
        case "refusal": self = .refusal
        default: self = .unknown(text)
        }
    }
}

/// A source that the answer cites: where it is, its title, and the passage that was cited.
public struct AICitation: Sendable, Equatable {
    public let url: String
    public let title: String
    public let citedText: String

    public init(url: String, title: String, citedText: String) {
        self.url = url
        self.title = title
        self.citedText = citedText
    }

    /// A citation as the platform writes it inside a text block.
    init(wire json: JSONValue) {
        url = json["url"]?.string ?? ""
        title = json["title"]?.string ?? json["document_title"]?.string ?? ""
        citedText = json["cited_text"]?.string ?? ""
    }
}

/// The image formats that the API takes.
public enum ImageMediaType: String, Sendable, Equatable, CaseIterable {
    case png = "image/png"
    case jpeg = "image/jpeg"
    case gif = "image/gif"
    case webp = "image/webp"
}

/// An image with its pixel size. The caller states the size; this module does not decode images.
public struct AIImage: Sendable, Equatable {
    public var data: Data
    public var mediaType: ImageMediaType
    public var width: Int
    public var height: Int

    public init(data: Data, mediaType: ImageMediaType, width: Int, height: Int) {
        self.data = data
        self.mediaType = mediaType
        self.width = width
        self.height = height
    }
}

/// The answer of the API. Its blocks are kept as they came, so that they can go back unchanged in the next request.
public struct AIResponse: Sendable, Equatable {
    public var blocks: [AIBlock]
    public var stopReason: AIStopReason?
    public var usage: AIUsage
    public var model: String
    public var requestID: String?

    public init(blocks: [AIBlock], stopReason: AIStopReason?, usage: AIUsage, model: String, requestID: String?) {
        self.blocks = blocks
        self.stopReason = stopReason
        self.usage = usage
        self.model = model
        self.requestID = requestID
    }

    /// An answer with plain text only, as the tests build it.
    public init(text: String, stopReason: AIStopReason?, usage: AIUsage, model: String, requestID: String?) {
        let blocks: [AIBlock] = text.isEmpty
            ? []
            : [.raw(.object(["type": .string("text"), "text": .string(text)]))]
        self.init(blocks: blocks, stopReason: stopReason, usage: usage, model: model, requestID: requestID)
    }

    /// The text of the answer: the text blocks, in order.
    public var text: String {
        blocks.compactMap { block -> String? in
            guard case let .raw(json) = block, json["type"]?.string == "text" else { return nil }
            return json["text"]?.string
        }
        .joined()
    }

    /// The calls of tools, in the order of the answer.
    public var toolCalls: [AIToolCall] {
        blocks.compactMap { block -> AIToolCall? in
            guard case let .toolUse(id, name, input) = block else { return nil }
            return AIToolCall(id: id, name: name, input: input)
        }
    }

    /// The sources that the text blocks cite, in the order of the answer.
    public var citations: [AICitation] {
        blocks.flatMap { block -> [AICitation] in
            guard case let .raw(json) = block, json["type"]?.string == "text",
                  case let .array(items)? = json["citations"] else {
                return []
            }
            return items.map { AICitation(wire: $0) }
        }
    }
}

/// A call of a tool by the model. The id must come back with the result of the tool.
public struct AIToolCall: Sendable, Equatable {
    public let id: String
    public let name: String
    public let input: JSONValue

    public init(id: String, name: String, input: JSONValue) {
        self.id = id
        self.name = name
        self.input = input
    }
}

/// The tokens of one call, as the API counts them.
public struct AIUsage: Sendable, Equatable {
    public var inputTokens: Int
    public var outputTokens: Int
    public var cacheReadTokens: Int
    /// All cache writes; the sum of the two buckets below.
    public var cacheWriteTokens: Int
    /// Cache writes with the five-minute time to live.
    public var cacheWrite5mTokens: Int
    /// Cache writes with the one-hour time to live.
    public var cacheWrite1hTokens: Int

    public init(
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        cacheReadTokens: Int = 0,
        cacheWriteTokens: Int = 0,
        cacheWrite5mTokens: Int = 0,
        cacheWrite1hTokens: Int = 0
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadTokens = cacheReadTokens
        self.cacheWriteTokens = cacheWriteTokens
        self.cacheWrite5mTokens = cacheWrite5mTokens
        self.cacheWrite1hTokens = cacheWrite1hTokens
    }
}
