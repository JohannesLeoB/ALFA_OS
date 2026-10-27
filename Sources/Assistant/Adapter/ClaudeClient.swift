import Foundation
import Hub

public struct ClaudeClient: ConversationPort {
    static let volatileMarker = "\n\u{1D}\n"
    public static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    static let apiVersion = "2023-06-01"
    static let plainTimeout: TimeInterval = 30
    static let attachmentTimeout: TimeInterval = 90

    private let keys: any KeyPort
    private let http: any HttpPort
    private let attachments: AttachmentStore?
    private let baseURL: URL

    public init(keys: any KeyPort, http: any HttpPort, attachments: AttachmentStore? = nil,
                baseURL: URL = ClaudeClient.endpoint) {
        self.keys = keys
        self.http = http
        self.attachments = attachments
        self.baseURL = baseURL
    }

    public func respond(_ request: ChatRequest) async throws -> Reply {
        guard let key = await keys.claudeKey() else { throw ClaudeFailure.notConnected }
        let urlRequest = try build(request, key: key, stream: false)
        let (data, response) = try await http.data(for: urlRequest)
        guard let status = response as? HTTPURLResponse else { throw ClaudeFailure.invalidResponse }
        guard (200...299).contains(status.statusCode) else { throw Self.failure(status: status.statusCode, response: status) }
        return try Self.parse(data)
    }

    public func stream(_ request: ChatRequest) -> AsyncThrowingStream<String, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let key = await keys.claudeKey() else { throw ClaudeFailure.notConnected }
                    let urlRequest = try build(request, key: key, stream: true)
                    let (lines, response) = try await http.lines(for: urlRequest)
                    guard let status = response as? HTTPURLResponse else { throw ClaudeFailure.invalidResponse }
                    guard (200...299).contains(status.statusCode) else {
                        throw Self.failure(status: status.statusCode, response: status)
                    }
                    for try await line in lines {
                        if let delta = try Self.delta(from: line) { continuation.yield(delta) }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func build(_ request: ChatRequest, key: ClaudeKey, stream: Bool) throws -> URLRequest {
        var tools = request.tools
        if var last = tools.popLast() {
            last.cacheControl = CacheControl()
            tools.append(last)
        }
        let payload = WirePayload(
            model: request.model ?? key.model, maxTokens: request.maxTokens,
            system: Self.systemBlocks(from: request.system),
            messages: Self.sanitize(wire(request.messages)),
            tools: tools.isEmpty ? nil : tools,
            stream: stream ? true : nil)
        var urlRequest = URLRequest(url: baseURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(key.apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        urlRequest.httpBody = try encoder.encode(payload)
        urlRequest.timeoutInterval = Self.attachmentCarrier(in: request.messages) == nil ? Self.plainTimeout : Self.attachmentTimeout
        return urlRequest
    }

    static func hasAttachment(_ message: Message) -> Bool {
        message.blocks.contains {
            switch $0 {
            case .image, .document: true
            default: false
            }
        }
    }

    static func attachmentCarrier(in messages: [Message]) -> UUID? {
        messages.last { $0.role == .user && hasAttachment($0) }?.id
    }

    func wire(_ messages: [Message]) -> [WireMessage] {
        let carrier = Self.attachmentCarrier(in: messages)
        return messages.map { wire($0, withAttachmentData: $0.id == carrier) }
    }

    func attachmentBlock(_ ref: AttachmentRef, withData: Bool) -> WireBlock {
        let placeholder = WireBlock.text("[attachment: \(ref.fileName)]")
        guard withData, let data = attachments?.data(for: ref),
              let kind = AttachmentStore.kind(forMimeType: ref.mimeType) else { return placeholder }
        switch kind {
        case .image:
            return .image(mediaType: ref.mimeType, base64: data.base64EncodedString())
        case .pdf:
            return .document(mediaType: ref.mimeType, base64: data.base64EncodedString(), title: ref.fileName)
        case .text:
            guard let text = String(data: data, encoding: .utf8) else { return placeholder }
            return .textDocument(text: String(text.prefix(AttachmentStore.textCharacterLimit)), title: ref.fileName)
        }
    }

    func wire(_ message: Message, withAttachmentData: Bool) -> WireMessage {
        var blocks: [WireBlock] = []
        for block in message.blocks {
            switch block {
            case .text(let text):
                blocks.append(.text(text))
            case .toolUse(let id, let name, let inputJSON):
                let input = (try? JSONDecoder().decode(JSONValue.self, from: inputJSON)) ?? .object([:])
                blocks.append(.toolUse(id: id, name: name, input: input))
            case .toolResult(let toolUseID, let summary, let isError):
                blocks.append(.toolResult(toolUseID: toolUseID, content: summary, isError: isError))
            case .image(let ref), .document(let ref):
                blocks.insert(attachmentBlock(ref, withData: withAttachmentData), at: 0)
            case .toolActivity, .calendarLink, .contactDraft, .mailDraft, .driveFiles, .estimate, .estimateBreakdown,
                 .airtableContactDraft, .taskChangeDraft, .appointmentDraft, .cartDraft, .fileDraft, .unreadable:
                break
            }
        }
        if blocks.isEmpty { blocks = [.text(" ")] }
        return WireMessage(role: message.role.rawValue, content: blocks)
    }

    static func sanitize(_ messages: [WireMessage]) -> [WireMessage] {
        var cleaned: [WireMessage] = []
        for message in messages {
            let content = message.content.filter { isBlank($0) == false }
            guard content.isEmpty == false else { continue }
            cleaned.append(WireMessage(role: message.role, content: content))
        }
        while let first = cleaned.first, first.role != "user", first.content.allSatisfy(isText) {
            cleaned.removeFirst()
        }
        var merged: [WireMessage] = []
        for message in cleaned {
            if var last = merged.last, last.role == message.role {
                last.content += message.content
                merged[merged.count - 1] = last
            } else {
                merged.append(message)
            }
        }
        if merged.isEmpty { return [WireMessage(role: "user", content: [.text("\u{2026}")])] }
        return merged
    }

    private static func isBlank(_ block: WireBlock) -> Bool {
        if case .text(let text) = block { return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return false
    }

    private static func isText(_ block: WireBlock) -> Bool {
        if case .text = block { return true }
        return false
    }

    static func systemBlocks(from system: String) -> [SystemBlock] {
        let parts = system.components(separatedBy: volatileMarker)
        guard parts.count == 2, parts[1].isEmpty == false else {
            return [SystemBlock(text: system, cacheControl: CacheControl())]
        }
        return [SystemBlock(text: parts[0], cacheControl: CacheControl()), SystemBlock(text: parts[1], cacheControl: nil)]
    }

    static func usage(_ object: [String: Any]) -> TokenUsage? {
        guard let usage = object["usage"] as? [String: Any] else { return nil }
        func number(_ key: String) -> Int { usage[key] as? Int ?? 0 }
        return TokenUsage(input: number("input_tokens"), output: number("output_tokens"),
                          cacheRead: number("cache_read_input_tokens"), cacheWrite: number("cache_creation_input_tokens"))
    }

    static func parse(_ data: Data) throws -> Reply {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeFailure.decodingFailed
        }
        var texts: [String] = []
        var toolUses: [ToolUse] = []
        for block in object["content"] as? [[String: Any]] ?? [] {
            switch block["type"] as? String {
            case "text":
                if let text = (block["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), text.isEmpty == false {
                    texts.append(text)
                }
            case "tool_use":
                let input = block["input"] as? [String: Any] ?? [:]
                let inputData = (try? JSONSerialization.data(withJSONObject: input)) ?? Data("{}".utf8)
                toolUses.append(ToolUse(id: block["id"] as? String ?? "", name: block["name"] as? String ?? "", inputJSON: inputData))
            default:
                break
            }
        }
        return Reply(text: texts.joined(separator: "\n\n"), toolUses: toolUses,
                     stopReason: object["stop_reason"] as? String, usage: usage(object))
    }

    static func delta(from line: String) throws -> String? {
        guard line.hasPrefix("data: ") else { return nil }
        let json = String(line.dropFirst(6))
        guard json != "[DONE]", let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if object["type"] as? String == "error" { throw ClaudeFailure.streamInterrupted }
        guard object["type"] as? String == "content_block_delta",
              let delta = object["delta"] as? [String: Any],
              delta["type"] as? String == "text_delta" else { return nil }
        return delta["text"] as? String
    }

    static func failure(status: Int, response: HTTPURLResponse) -> ClaudeFailure {
        switch status {
        case 429: .rateLimited(retryAfter: response.value(forHTTPHeaderField: "retry-after").flatMap { Int($0) })
        case 529: .overloaded
        default: .httpError(status)
        }
    }
}
