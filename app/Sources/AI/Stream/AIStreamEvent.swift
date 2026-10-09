import Foundation

/// One event of a streamed answer, reduced to what the app reads. Events without meaning for the app are dropped.
public enum AIStreamEvent: Sendable, Equatable {
    case messageStart(id: String, model: String, usage: AIUsage)
    case textDelta(index: Int, text: String)
    case toolUseStart(index: Int, id: String, name: String)
    case serverToolUseStart(index: Int, id: String, name: String)
    case toolInputDelta(index: Int, partialJSON: String)
    /// A block that arrives whole when it starts, such as the result of a web search.
    case rawBlock(index: Int, block: JSONValue)
    case blockStop(index: Int)
    case messageDelta(stopReason: AIStopReason?, usage: AIUsage?)
    case messageStop
    /// The stream reported an error. It ends the stream.
    case error(AIError)
}

/// Reads one frame of the stream into an event. Ping frames, thinking deltas and unknown events give nil.
enum AIStreamDecoder {
    /// The longest message that the app keeps from an error event.
    static let maxMessageLength = 300

    static func event(from frame: SSEFrame) -> AIStreamEvent? {
        guard !frame.data.isEmpty else { return nil }
        guard let json = try? JSONDecoder().decode(JSONValue.self, from: Data(frame.data.utf8)) else {
            return .error(.decoding)
        }
        let type = json["type"]?.string ?? frame.event ?? ""
        switch type {
        case "message_start":
            let message = json["message"]
            return .messageStart(
                id: message?["id"]?.string ?? "",
                model: message?["model"]?.string ?? "",
                usage: usage(message?["usage"])
            )
        case "content_block_start":
            return blockStart(json)
        case "content_block_delta":
            return blockDelta(json)
        case "content_block_stop":
            guard let index = json["index"]?.int else { return nil }
            return .blockStop(index: index)
        case "message_delta":
            let usageValue = json["usage"].map { usage($0) }
            let reason = json["delta"]?["stop_reason"]?.string.map(AIStopReason.init(wire:))
            return .messageDelta(stopReason: reason, usage: usageValue)
        case "message_stop":
            return .messageStop
        case "error":
            return .error(apiError(json["error"]))
        default:
            return nil
        }
    }

    private static func blockStart(_ json: JSONValue) -> AIStreamEvent? {
        guard let index = json["index"]?.int, let block = json["content_block"] else { return nil }
        let kind = block["type"]?.string ?? ""
        switch kind {
        case "tool_use":
            return .toolUseStart(index: index, id: block["id"]?.string ?? "", name: block["name"]?.string ?? "")
        case "server_tool_use":
            return .serverToolUseStart(index: index, id: block["id"]?.string ?? "", name: block["name"]?.string ?? "")
        case "text", "thinking", "redacted_thinking":
            return nil
        default:
            // Results such as web_search_tool_result or web_fetch_tool_result arrive whole.
            return kind.hasSuffix("_tool_result") ? .rawBlock(index: index, block: block) : nil
        }
    }

    private static func blockDelta(_ json: JSONValue) -> AIStreamEvent? {
        guard let index = json["index"]?.int, let delta = json["delta"] else { return nil }
        switch delta["type"]?.string {
        case "text_delta":
            return .textDelta(index: index, text: delta["text"]?.string ?? "")
        case "input_json_delta":
            return .toolInputDelta(index: index, partialJSON: delta["partial_json"]?.string ?? "")
        default:
            // thinking_delta, signature_delta and deltas of unknown kinds.
            return nil
        }
    }

    /// The token counts of an answer. Missing counts read as zero.
    static func usage(_ value: JSONValue?) -> AIUsage {
        let creation = value?["cache_creation"]
        return AIUsage(
            inputTokens: value?["input_tokens"]?.int ?? 0,
            outputTokens: value?["output_tokens"]?.int ?? 0,
            cacheReadTokens: value?["cache_read_input_tokens"]?.int ?? 0,
            cacheWriteTokens: value?["cache_creation_input_tokens"]?.int ?? 0,
            cacheWrite5mTokens: creation?["ephemeral_5m_input_tokens"]?.int ?? 0,
            cacheWrite1hTokens: creation?["ephemeral_1h_input_tokens"]?.int ?? 0
        )
    }

    /// The error of an error event. An overloaded error is the busy answer (529).
    static func apiError(_ value: JSONValue?) -> AIError {
        let kind = value?["type"]?.string ?? ""
        let message = String((value?["message"]?.string ?? kind).prefix(maxMessageLength))
        switch kind {
        case "overloaded_error":
            return .overloaded(status: 529)
        case "rate_limit_error":
            return .rateLimited(retryAfter: nil)
        case "authentication_error":
            return .invalidKey
        case "permission_error":
            return .forbidden
        case "invalid_request_error":
            return .badRequest(message)
        case "api_error":
            return .overloaded(status: 500)
        default:
            return .unusableAnswer("the stream reported an error")
        }
    }
}
