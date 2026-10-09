import Foundation

/// The JSON of the Messages API: the body of a request and the reading of an answer.
enum AnthropicWire {
    static func body(for request: AIRequest, stream: Bool = false) throws -> Data {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.sortedKeys]
        var messages: [WireMessage] = []
        for message in request.messages {
            for case let .image(image) in message.blocks {
                try AIImageRules.check(image)
            }
            messages.append(WireMessage(
                role: message.role.rawValue,
                content: try message.blocks.map(wireValue(for:))
            ))
        }
        let wire = WireRequest(
            model: request.model,
            maxTokens: request.maxTokens,
            system: request.system,
            messages: messages,
            temperature: request.temperature,
            cacheControl: cacheControl(for: request.cache),
            tools: request.tools.isEmpty ? nil : try AIToolWire.tools(request.tools),
            stream: stream ? true : nil,
            thinking: request.thinking.map { .object(["type": .string($0.wireName)]) },
            outputConfig: outputConfig(effort: request.effort, format: request.format)
        )
        return try encoder.encode(wire)
    }

    /// The effort and the answer format in one field. Absent when neither is set.
    static func outputConfig(effort: AIEffort?, format: AIOutputFormat?) -> JSONValue? {
        var object: [String: JSONValue] = [:]
        if let effort {
            object["effort"] = .string(effort.rawValue)
        }
        if let format {
            switch format {
            case let .jsonSchema(schema):
                object["format"] = .object(["type": .string("json_schema"), "schema": schema])
            }
        }
        return object.isEmpty ? nil : .object(object)
    }

    /// The top-level cache field. Absent when the cache is off; the time to live is sent only for one hour.
    static func cacheControl(for policy: AICachePolicy) -> WireCacheControl? {
        switch policy {
        case .off:
            return nil
        case let .automatic(ttl):
            switch ttl {
            case .fiveMinutes:
                return WireCacheControl(type: "ephemeral", ttl: nil)
            case .oneHour:
                return WireCacheControl(type: "ephemeral", ttl: "1h")
            }
        }
    }

    /// The JSON of one block of a message. Blocks of an answer go back in their own form.
    static func wireValue(for block: AIBlock) throws -> JSONValue {
        switch block {
        case let .text(text):
            return .object(["type": .string("text"), "text": .string(text)])
        case let .image(image):
            return .object([
                "type": .string("image"),
                "source": .object([
                    "type": .string("base64"),
                    "media_type": .string(image.mediaType.rawValue),
                    "data": .string(image.data.base64EncodedString()),
                ]),
            ])
        case let .toolUse(id, name, input):
            return .object(["type": .string("tool_use"), "id": .string(id), "name": .string(name), "input": input])
        case let .toolResult(toolUseID, content, isError):
            var object: [String: JSONValue] = [
                "type": .string("tool_result"),
                "tool_use_id": .string(toolUseID),
                "content": .string(content),
            ]
            if isError {
                object["is_error"] = .bool(true)
            }
            return .object(object)
        case let .serverToolUse(id, name, input):
            return .object(["type": .string("server_tool_use"), "id": .string(id), "name": .string(name), "input": input])
        case let .webSearchToolResult(toolUseID, content):
            return .object([
                "type": .string("web_search_tool_result"),
                "tool_use_id": .string(toolUseID),
                "content": content,
            ])
        case let .raw(json):
            return json
        }
    }

    /// Reads an answer: its blocks as they came, the stop reason and the token counts.
    static func response(from data: Data, requestID: String?) throws -> AIResponse {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let wire = try? decoder.decode(WireResponse.self, from: data) else {
            throw AIError.decoding
        }
        // The blocks are read without key conversion, so that their keys stay as the platform wrote them.
        guard let content = try? JSONDecoder().decode(WireContent.self, from: data) else {
            throw AIError.decoding
        }
        let breakdown = try? JSONDecoder().decode(WireCacheBreakdown.self, from: data)
        let usage = AIUsage(
            inputTokens: wire.usage?.inputTokens ?? 0,
            outputTokens: wire.usage?.outputTokens ?? 0,
            cacheReadTokens: wire.usage?.cacheReadInputTokens ?? 0,
            cacheWriteTokens: wire.usage?.cacheCreationInputTokens ?? 0,
            cacheWrite5mTokens: breakdown?.usage?.cacheCreation?.ephemeral5m ?? 0,
            cacheWrite1hTokens: breakdown?.usage?.cacheCreation?.ephemeral1h ?? 0
        )
        return AIResponse(
            blocks: content.content.map(AIBlock.init(wire:)),
            stopReason: wire.stopReason.map(AIStopReason.init(wire:)),
            usage: usage,
            model: wire.model ?? "",
            requestID: requestID ?? wire.id
        )
    }
}

private struct WireRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String
    let messages: [WireMessage]
    let temperature: Double?
    let cacheControl: WireCacheControl?
    let tools: [JSONValue]?
    let stream: Bool?
    let thinking: JSONValue?
    let outputConfig: JSONValue?
}

/// The top-level `cache_control` field. `ttl` is absent for the five-minute default.
struct WireCacheControl: Encodable, Equatable {
    let type: String
    let ttl: String?
}

private struct WireMessage: Encodable {
    let role: String
    let content: [JSONValue]
}

private struct WireResponse: Decodable {
    let id: String?
    let model: String?
    let stopReason: String?
    let usage: WireUsage?
}

/// The blocks of an answer, as they came.
private struct WireContent: Decodable {
    let content: [JSONValue]
}

private struct WireUsage: Decodable {
    let inputTokens: Int?
    let outputTokens: Int?
    let cacheCreationInputTokens: Int?
    let cacheReadInputTokens: Int?
}

/// The cache writes of one answer, split by time to live. It is read by a decoder without key conversion,
/// so that the snake case keys of the answer match exactly.
private struct WireCacheBreakdown: Decodable {
    let usage: Usage?

    struct Usage: Decodable {
        let cacheCreation: Buckets?

        enum CodingKeys: String, CodingKey {
            case cacheCreation = "cache_creation"
        }
    }

    struct Buckets: Decodable {
        let ephemeral5m: Int?
        let ephemeral1h: Int?

        enum CodingKeys: String, CodingKey {
            case ephemeral5m = "ephemeral_5m_input_tokens"
            case ephemeral1h = "ephemeral_1h_input_tokens"
        }
    }
}
