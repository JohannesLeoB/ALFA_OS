import Foundation
import MykilosKit

public struct ClaudeToolUse: Sendable, Equatable {
    public let id: String
    public let name: String
    public let inputJSON: Data
}

public struct ClaudeTokenUsage: Sendable, Equatable {
    public let input: Int
    public let output: Int
    public let cacheRead: Int
    public let cacheWrite: Int

    public init(input: Int, output: Int, cacheRead: Int, cacheWrite: Int) {
        self.input = input
        self.output = output
        self.cacheRead = cacheRead
        self.cacheWrite = cacheWrite
    }

    public var billedInput: Int { input + cacheWrite }

    public var cacheShare: Double {
        let total = input + cacheRead + cacheWrite
        return total == 0 ? 0 : Double(cacheRead) / Double(total)
    }
}

public struct ClaudeChatResponse: Sendable, Equatable {
    public let text: String
    public let toolUses: [ClaudeToolUse]
    public let stopReason: String?
    public let usage: ClaudeTokenUsage?

    public init(text: String, toolUses: [ClaudeToolUse], stopReason: String?,
                usage: ClaudeTokenUsage? = nil) {
        self.text = text
        self.toolUses = toolUses
        self.stopReason = stopReason
        self.usage = usage
    }
}

enum ClaudeWireBlock: Encodable, Equatable {
    case text(String)
    case toolUse(id: String, name: String, input: [String: String])
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

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let t):
            try c.encode("text", forKey: .type); try c.encode(t, forKey: .text)
        case .toolUse(let id, let name, let input):
            try c.encode("tool_use", forKey: .type)
            try c.encode(id, forKey: .id); try c.encode(name, forKey: .name); try c.encode(input, forKey: .input)
        case .toolResult(let tid, let content, let isError):
            try c.encode("tool_result", forKey: .type)
            try c.encode(tid, forKey: .toolUseID); try c.encode(content, forKey: .content); try c.encode(isError, forKey: .isError)
        case .image(let mediaType, let base64):
            try c.encode("image", forKey: .type)
            var src = c.nestedContainer(keyedBy: SourceKeys.self, forKey: .source)
            try src.encode("base64", forKey: .type); try src.encode(mediaType, forKey: .mediaType); try src.encode(base64, forKey: .data)
        case .document(let mediaType, let base64, let title):
            try c.encode("document", forKey: .type); try c.encode(title, forKey: .title)
            var src = c.nestedContainer(keyedBy: SourceKeys.self, forKey: .source)
            try src.encode("base64", forKey: .type); try src.encode(mediaType, forKey: .mediaType); try src.encode(base64, forKey: .data)
        case .textDocument(let text, let title):
            try c.encode("document", forKey: .type); try c.encode(title, forKey: .title)
            var src = c.nestedContainer(keyedBy: SourceKeys.self, forKey: .source)
            try src.encode("text", forKey: .type); try src.encode("text/plain", forKey: .mediaType); try src.encode(text, forKey: .data)
        }
    }
}

struct ClaudeWireMessage: Encodable, Equatable {
    var role: String
    var content: [ClaudeWireBlock]
}

public struct ClaudeCacheControl: Encodable, Equatable {
    let type = "ephemeral"
    public init() {}
}

struct ClaudeSystemBlock: Encodable, Equatable {
    let type = "text"
    let text: String
    var cacheControl: ClaudeCacheControl?
    enum CodingKeys: String, CodingKey { case type, text, cacheControl = "cache_control" }
}

struct ClaudeChatRequestPayload: Encodable {
    var model: String
    var maxTokens: Int
    var system: [ClaudeSystemBlock]
    var messages: [ClaudeWireMessage]
    var tools: [ClaudeToolDefinition]?
    var stream: Bool?

    enum CodingKeys: String, CodingKey {
        case model, maxTokens = "max_tokens", system, messages, tools, stream
    }
}

public struct ClaudeChatClient: AssistantConversing {
    private let credentialsStore: ClaudeCredentialsStoring
    private let httpClient: ClaudeHTTPClient
    private let baseURL: URL

    public init(
        credentialsStore: ClaudeCredentialsStoring = KeychainClaudeCredentialsStore(),
        httpClient: ClaudeHTTPClient = URLSession.shared,
        baseURL: URL = URL(string: "https://api.anthropic.com/v1/messages")!
    ) {
        self.credentialsStore = credentialsStore
        self.httpClient = httpClient
        self.baseURL = baseURL
    }

    public func respond(
        messages: [ChatMessage], system: String, tools: [ClaudeToolDefinition], maxTokens: Int
    ) async throws -> ClaudeChatResponse {
        try await respond(messages: messages, system: system, tools: tools, maxTokens: maxTokens, model: nil)
    }

    public func respond(
        messages: [ChatMessage], system: String, tools: [ClaudeToolDefinition], maxTokens: Int, model: String?
    ) async throws -> ClaudeChatResponse {
        guard let credentials = try credentialsStore.load() else { throw ClaudeClientError.notConnected }
        let request = try Self.buildRequest(
            url: baseURL, credentials: credentials, messages: messages, system: system, tools: tools,
            maxTokens: maxTokens, modelOverride: model
        )
        let (data, response) = try await httpClient.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClaudeClientError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw Self.mapHTTPError(status: http.statusCode, response: http) }
        return try Self.parseResponse(from: data)
    }

    public func chat(messages: [ChatMessage], system: String, maxTokens: Int = 1024) async throws -> String {
        let response = try await respond(messages: messages, system: system, tools: [], maxTokens: maxTokens)
        guard response.text.isEmpty == false else { throw ClaudeClientError.emptyResponse }
        return response.text
    }

    static let volatileSystemMarker = "\n\u{1D}\n"

    static func buildRequest(
        url: URL, credentials: ClaudeCredentials, messages: [ChatMessage],
        system: String, tools: [ClaudeToolDefinition], maxTokens: Int,
        stream: Bool = false, modelOverride: String? = nil
    ) throws -> URLRequest {
        let systemBlocks = systemBlocks(from: system)

        var wireTools = tools
        if var last = wireTools.popLast() {
            last.cacheControl = ClaudeCacheControl()
            wireTools.append(last)
        }
        let payload = ClaudeChatRequestPayload(
            model: modelOverride ?? credentials.model, maxTokens: maxTokens, system: systemBlocks,
            messages: sanitize(wire(messages)),
            tools: wireTools.isEmpty ? nil : wireTools,
            stream: stream ? true : nil
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(credentials.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONEncoder().encode(payload)

        request.timeoutInterval = attachmentCarrier(in: messages) == nil ? 30 : 90
        return request
    }

    static func hasAttachment(_ message: ChatMessage) -> Bool {
        message.blocks.contains {
            switch $0 {
            case .image, .document: true
            default: false
            }
        }
    }

    static func attachmentCarrier(in messages: [ChatMessage]) -> UUID? {
        messages.last { $0.role == .user && hasAttachment($0) }?.id
    }

    static func wire(_ messages: [ChatMessage]) -> [ClaudeWireMessage] {
        let carrier = attachmentCarrier(in: messages)
        return messages.map { wire(from: $0, withAttachmentData: $0.id == carrier) }
    }

    static func attachmentBlock(_ ref: ChatAttachmentRef, withData: Bool) -> ClaudeWireBlock {
        let placeholder = ClaudeWireBlock.text("[Anhang: \(ref.fileName)]")
        guard withData, let data = ChatAttachmentStore.data(for: ref),
              let kind = ChatAttachmentStore.kind(forMimeType: ref.mimeType) else { return placeholder }
        switch kind {
        case .image:
            return .image(mediaType: ref.mimeType, base64: data.base64EncodedString())
        case .pdf:
            return .document(mediaType: ref.mimeType, base64: data.base64EncodedString(), title: ref.fileName)
        case .text:
            guard let text = String(data: data, encoding: .utf8) else { return placeholder }
            return .textDocument(text: String(text.prefix(ChatAttachmentStore.textCharacterLimit)), title: ref.fileName)
        }
    }

    static func wire(from message: ChatMessage, withAttachmentData: Bool = false) -> ClaudeWireMessage {
        var blocks: [ClaudeWireBlock] = []
        for block in message.blocks {
            switch block {
            case .text(let t):
                blocks.append(.text(t))
            case .toolUse(let id, let name, let inputJSON):
                let input = (try? JSONDecoder().decode([String: String].self, from: inputJSON)) ?? [:]
                blocks.append(.toolUse(id: id, name: name, input: input))
            case .toolResult(let tid, let summary, let isError):
                blocks.append(.toolResult(toolUseID: tid, content: summary, isError: isError))
            case .toolActivity, .calendarAction, .contactAction, .draftAction, .driveFiles, .kalkulationsSchaetzung, .estimateBreakdown, .airtableContactAction, .clickUpAction, .terminAction, .warenkorbAction, .dateiAction:
                break
            case .image(let ref), .document(let ref):
                blocks.insert(attachmentBlock(ref, withData: withAttachmentData), at: 0)
            }
        }
        if blocks.isEmpty { blocks = [.text(" ")] }
        return ClaudeWireMessage(role: message.role.rawValue, content: blocks)
    }

    static func sanitize(_ messages: [ClaudeWireMessage]) -> [ClaudeWireMessage] {
        var cleaned: [ClaudeWireMessage] = []
        for message in messages {
            let content = message.content.filter { isBlankText($0) == false }
            guard content.isEmpty == false else { continue }
            cleaned.append(ClaudeWireMessage(role: message.role, content: content))
        }

        while let first = cleaned.first,
              first.role != "user",
              first.content.allSatisfy(isTextBlock) {
            cleaned.removeFirst()
        }

        var merged: [ClaudeWireMessage] = []
        for message in cleaned {
            if var last = merged.last, last.role == message.role {
                last.content += message.content
                merged[merged.count - 1] = last
            } else {
                merged.append(message)
            }
        }

        if merged.isEmpty { return [ClaudeWireMessage(role: "user", content: [.text("…")])] }
        return merged
    }

    private static func isBlankText(_ block: ClaudeWireBlock) -> Bool {
        if case .text(let t) = block { return t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return false
    }

    private static func isTextBlock(_ block: ClaudeWireBlock) -> Bool {
        if case .text = block { return true }
        return false
    }

    static func systemBlocks(from system: String) -> [ClaudeSystemBlock] {
        let parts = system.components(separatedBy: volatileSystemMarker)
        guard parts.count == 2, parts[1].isEmpty == false else {
            return [ClaudeSystemBlock(text: system, cacheControl: ClaudeCacheControl())]
        }
        return [
            ClaudeSystemBlock(text: parts[0], cacheControl: ClaudeCacheControl()),
            ClaudeSystemBlock(text: parts[1], cacheControl: nil)
        ]
    }

    static func parseUsage(_ obj: [String: Any]) -> ClaudeTokenUsage? {
        guard let usage = obj["usage"] as? [String: Any] else { return nil }
        func number(_ key: String) -> Int { usage[key] as? Int ?? 0 }
        return ClaudeTokenUsage(
            input: number("input_tokens"),
            output: number("output_tokens"),
            cacheRead: number("cache_read_input_tokens"),
            cacheWrite: number("cache_creation_input_tokens"))
    }

    static func parseResponse(from data: Data) throws -> ClaudeChatResponse {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeClientError.decodingFailed
        }
        let stopReason = obj["stop_reason"] as? String
        let content = obj["content"] as? [[String: Any]] ?? []
        var texts: [String] = []
        var toolUses: [ClaudeToolUse] = []
        for block in content {
            switch block["type"] as? String {
            case "text":
                if let t = (block["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), t.isEmpty == false {
                    texts.append(t)
                }
            case "tool_use":
                let id = block["id"] as? String ?? ""
                let name = block["name"] as? String ?? ""
                let input = block["input"] as? [String: Any] ?? [:]
                let inputData = (try? JSONSerialization.data(withJSONObject: input)) ?? Data("{}".utf8)
                toolUses.append(ClaudeToolUse(id: id, name: name, inputJSON: inputData))
            default:
                break
            }
        }
        return ClaudeChatResponse(text: texts.joined(separator: "\n\n"), toolUses: toolUses,
                                  stopReason: stopReason, usage: parseUsage(obj))
    }

    public func streamText(
        messages: [ChatMessage], system: String, tools: [ClaudeToolDefinition], maxTokens: Int
    ) -> AsyncThrowingStream<String, Error> {
        streamText(messages: messages, system: system, tools: tools, maxTokens: maxTokens, model: nil)
    }

    public func streamText(
        messages: [ChatMessage], system: String, tools: [ClaudeToolDefinition], maxTokens: Int, model: String?
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let credentials = try credentialsStore.load() else {
                        continuation.finish(throwing: ClaudeClientError.notConnected)
                        return
                    }
                    let request = try Self.buildRequest(
                        url: baseURL, credentials: credentials,
                        messages: messages, system: system, tools: tools,
                        maxTokens: maxTokens, stream: true, modelOverride: model
                    )
                    let (bytes, response) = try await URLSession.shared.bytes(for: request, delegate: nil)
                    guard let http = response as? HTTPURLResponse else {
                        continuation.finish(throwing: ClaudeClientError.invalidResponse)
                        return
                    }
                    guard (200...299).contains(http.statusCode) else {
                        continuation.finish(throwing: Self.mapHTTPError(status: http.statusCode, response: http))
                        return
                    }
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let json = String(line.dropFirst(6))
                        guard json != "[DONE]",
                              let data = json.data(using: .utf8),
                              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              obj["type"] as? String == "content_block_delta",
                              let delta = obj["delta"] as? [String: Any],
                              delta["type"] as? String == "text_delta",
                              let text = delta["text"] as? String
                        else { continue }
                        continuation.yield(text)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    static func mapHTTPError(status: Int, response: HTTPURLResponse) -> ClaudeClientError {
        switch status {
        case 429:
            let retry = response.value(forHTTPHeaderField: "retry-after").flatMap { Int($0) }
            return .rateLimited(retryAfter: retry)
        case 529:
            return .overloaded
        default:
            return .httpError(status)
        }
    }
}
