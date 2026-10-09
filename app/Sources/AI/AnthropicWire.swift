import Foundation

/// The JSON of the Messages API: the body of a request and the reading of an answer.
enum AnthropicWire {
    static func body(for request: AIRequest) throws -> Data {
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
            temperature: request.temperature
        )
        return try encoder.encode(wire)
    }

    /// Reads the text of an answer. Blocks other than text (for example thinking or tool use) are skipped.
    static func response(from data: Data, requestID: String?) throws -> AIResponse {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let wire = try? decoder.decode(WireResponse.self, from: data) else {
            throw AIError.decoding
        }
        let text = wire.content
            .filter { $0.type == "text" }
            .compactMap(\.text)
            .joined()
        let usage = AIUsage(
            inputTokens: wire.usage?.inputTokens ?? 0,
            outputTokens: wire.usage?.outputTokens ?? 0,
            cacheReadTokens: wire.usage?.cacheReadInputTokens ?? 0,
            cacheWriteTokens: wire.usage?.cacheCreationInputTokens ?? 0
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
