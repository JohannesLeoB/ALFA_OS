import Foundation

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

public struct Reply: Sendable, Equatable {
    public let text: String
    let toolUses: [ToolUse]
    let stopReason: String?
    public let usage: TokenUsage?

    public init(text: String, toolUses: [ToolUse], stopReason: String?, usage: TokenUsage? = nil) {
        self.text = text
        self.toolUses = toolUses
        self.stopReason = stopReason
        self.usage = usage
    }
}

public struct ToolUse: Sendable, Equatable {
    let id: String
    let name: String
    let inputJSON: Data

    init(id: String, name: String, inputJSON: Data) {
        self.id = id
        self.name = name
        self.inputJSON = inputJSON
    }
}

public struct TokenUsage: Sendable, Equatable {
    let input: Int
    let output: Int
    let cacheRead: Int
    let cacheWrite: Int

    init(input: Int, output: Int, cacheRead: Int, cacheWrite: Int) {
        self.input = input
        self.output = output
        self.cacheRead = cacheRead
        self.cacheWrite = cacheWrite
    }

    var cacheShare: Double {
        let total = input + cacheRead + cacheWrite
        return total == 0 ? 0 : Double(cacheRead) / Double(total)
    }
}

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

enum JSONValue: Codable, Sendable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }

    var scalarText: String? {
        switch self {
        case .string(let value):
            return value
        case .bool(let value):
            return value ? "true" : "false"
        case .number(let value):
            if value == value.rounded(), abs(value) < 1e15 { return String(Int64(value)) }
            return String(value)
        case .null, .array, .object:
            return nil
        }
    }
}

public enum ClaudeModelChoice: String, CaseIterable, Sendable {
    case standard
    case sonnet
    case haiku
    case opus

    public var id: String? {
        switch self {
        case .standard: nil
        case .sonnet: ModelRouter.sonnet
        case .haiku: ModelRouter.haiku
        case .opus: ModelRouter.opus
        }
    }

    public var key: String {
        self == .standard ? "settings.value.default" : "settings.model." + rawValue
    }

    public static func stored(_ id: String?) -> ClaudeModelChoice {
        allCases.first { $0.id != nil && $0.id == id } ?? .standard
    }
}

public struct UsageTotals: Equatable, Sendable {
    public var input: Int
    public var output: Int
    public var calls: Int
    public var since: Date?

    public init(input: Int = 0, output: Int = 0, calls: Int = 0, since: Date? = nil) {
        self.input = input
        self.output = output
        self.calls = calls
        self.since = since
    }
}

public enum UsagePrice: String, CaseIterable, Sendable {
    case input
    case output
}
