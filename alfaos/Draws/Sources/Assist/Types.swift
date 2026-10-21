import Foundation

public struct Tool: Sendable, Equatable {
    public var name: String
    public var description: String
    public var schema: JSON

    public init(name: String, description: String, schema: JSON) {
        self.name = name
        self.description = description
        self.schema = schema
    }

    var wire: JSON {
        ["name": .string(name), "description": .string(description), "input_schema": schema]
    }
}

public struct Finish: Sendable, Equatable {
    public var summary: String
    public var assumptions: [String]
    public var questions: [String]

    public init(summary: String, assumptions: [String] = [], questions: [String] = []) {
        self.summary = summary
        self.assumptions = assumptions
        self.questions = questions
    }

    public init?(input: JSON) {
        guard let summary = input["summary"]?.string else { return nil }
        self.init(summary: summary,
                  assumptions: input["assumptions"]?.array?.compactMap(\.string) ?? [],
                  questions: input["questions"]?.array?.compactMap(\.string) ?? [])
    }

    public static let tool = Tool(
        name: "finish",
        description: "End the session. Call it once, after the result is verified. Pass a short summary, every value you assumed and every open question.",
        schema: ["type": "object",
                 "properties": ["summary": ["type": "string"],
                                "assumptions": ["type": "array", "items": ["type": "string"]],
                                "questions": ["type": "array", "items": ["type": "string"]]],
                 "required": ["summary", "assumptions", "questions"]])
}

public struct ToolResult: Sendable {
    public enum Content: Sendable {
        case text(String)
        case json(JSON)
        case png(Data)
    }

    public var content: [Content]
    public var isError: Bool
    public var finish: Finish?

    public init(content: [Content], isError: Bool = false, finish: Finish? = nil) {
        self.content = content
        self.isError = isError
        self.finish = finish
    }

    public static func text(_ value: String) -> ToolResult { ToolResult(content: [.text(value)]) }

    public static func json(_ value: JSON) -> ToolResult { ToolResult(content: [.json(value)]) }

    public static func error(_ value: String) -> ToolResult { ToolResult(content: [.text(value)], isError: true) }

    var summary: String {
        for item in content {
            switch item {
            case .text(let value): return String(value.prefix(200))
            case .json(let value): return String(value.text.prefix(200))
            case .png: continue
            }
        }
        return ""
    }

    var image: Data? {
        for item in content {
            if case .png(let data) = item { return data }
        }
        return nil
    }

    func wire(id: String) -> JSON {
        var blocks: [JSON] = content.map { item in
            switch item {
            case .text(let value):
                return ["type": "text", "text": .string(value)]
            case .json(let value):
                return ["type": "text", "text": .string(value.text)]
            case .png(let data):
                return ["type": "image",
                        "source": ["type": "base64", "media_type": "image/png", "data": .string(data.base64EncodedString())]]
            }
        }
        if blocks.isEmpty { blocks = [["type": "text", "text": "ok"]] }
        var out: [String: JSON] = ["type": "tool_result", "tool_use_id": .string(id), "content": .array(blocks)]
        if isError { out["is_error"] = true }
        return .object(out)
    }
}

public protocol Toolbox: Sendable {
    var tools: [Tool] { get }
    func call(_ name: String, _ input: JSON) async -> ToolResult
}

public struct Media: Sendable, Equatable {
    public static let images = ["image/png", "image/jpeg", "image/gif", "image/webp"]
    public static let document = "application/pdf"

    public var label: String
    public var mediaType: String
    public var data: Data
    public var note: String

    public init(label: String, mediaType: String, data: Data = Data(), note: String = "") {
        self.label = label
        self.mediaType = mediaType
        self.data = data
        self.note = note
    }
}

public struct Budget: Sendable, Equatable {
    public var rounds: Int
    public var tokens: Int

    public init(rounds: Int = 40, tokens: Int = 150_000) {
        self.rounds = rounds
        self.tokens = tokens
    }
}

public enum Fault: Error, Sendable, Equatable {
    case noKey
    case noModel
    case emptyPrompt
    case tooLarge
    case truncated
    case http(Int, String)
    case malformed(String)
    case transport(String)
}

public enum Event: Sendable, Equatable {
    case thinking(String)
    case text(String)
    case toolCall(name: String, input: JSON)
    case toolResult(name: String, ok: Bool, summary: String)
    case image(Data)
    case finished(Finish)
    case stopped(String)
    case failed(Fault)
}
