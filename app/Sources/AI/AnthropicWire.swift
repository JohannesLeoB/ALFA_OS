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
            messages.append(WireMessage(message))
        }
        let wire = WireRequest(
            model: request.model,
            maxTokens: request.maxTokens,
            system: request.system,
            messages: messages,
            temperature: request.temperature,
            cacheControl: cacheControl(for: request.cache),
            stream: stream ? true : nil
        )
        return try encoder.encode(wire)
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

    /// Reads the text of an answer. Blocks other than text (for example thinking or tool use) are skipped.
    static func response(from data: Data, requestID: String?) throws -> AIResponse {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let wire = try? decoder.decode(WireResponse.self, from: data) else {
            throw AIError.decoding
        }
        let breakdown = try? JSONDecoder().decode(WireCacheBreakdown.self, from: data)
        let text = wire.content
            .filter { $0.type == "text" }
            .compactMap(\.text)
            .joined()
        let usage = AIUsage(
            inputTokens: wire.usage?.inputTokens ?? 0,
            outputTokens: wire.usage?.outputTokens ?? 0,
            cacheReadTokens: wire.usage?.cacheReadInputTokens ?? 0,
            cacheWriteTokens: wire.usage?.cacheCreationInputTokens ?? 0,
            cacheWrite5mTokens: breakdown?.usage?.cacheCreation?.ephemeral5m ?? 0,
            cacheWrite1hTokens: breakdown?.usage?.cacheCreation?.ephemeral1h ?? 0
        )
        return AIResponse(
            text: text,
            stopReason: wire.stopReason,
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
    let stream: Bool?
}

/// The top-level `cache_control` field. `ttl` is absent for the five-minute default.
struct WireCacheControl: Encodable, Equatable {
    let type: String
    let ttl: String?
}

private struct WireMessage: Encodable {
    let role: String
    let content: [WireBlock]

    init(_ message: AIMessage) {
        role = message.role.rawValue
        content = message.blocks.map(WireBlock.init)
    }
}

private struct WireBlock: Encodable {
    let type: String
    let text: String?
    let source: WireSource?

    init(_ block: AIBlock) {
        switch block {
        case let .text(text):
            type = "text"
            self.text = text
            source = nil
        case let .image(image):
            type = "image"
            text = nil
            source = WireSource(
                type: "base64",
                mediaType: image.mediaType.rawValue,
                data: image.data.base64EncodedString()
            )
        }
    }
}

private struct WireSource: Encodable {
    let type: String
    let mediaType: String
    let data: String
}

private struct WireResponse: Decodable {
    let id: String?
    let model: String?
    let content: [WireContent]
    let stopReason: String?
    let usage: WireUsage?
}

private struct WireContent: Decodable {
    let type: String?
    let text: String?
}

private struct WireUsage: Decodable {
    let inputTokens: Int?
    let outputTokens: Int?
    let cacheCreationInputTokens: Int?
    let cacheReadInputTokens: Int?
}

/// The cache writes of one call, split by time to live.
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
