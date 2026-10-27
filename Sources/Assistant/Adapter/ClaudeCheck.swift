import Hub

public struct ClaudeCheck: ConnectionCheckPort {
    static let probeText = "."
    static let probeTokens = 1
    static let overloadedStatus = 529
    static let rateLimitedStatus = 429

    private let http: any HttpPort

    public init(http: any HttpPort) {
        self.http = http
    }

    public var integration: String { "claude" }

    public func check(_ values: KeyValues) async throws -> String? {
        let model = values["model"].isEmpty ? ClaudeKey.defaultModel : values["model"]
        let client = ClaudeClient(keys: HeldKey(key: ClaudeKey(apiKey: values["key"], model: model)), http: http)
        let request = ChatRequest(messages: [Message.text(Self.probeText, role: .user)], system: "", maxTokens: Self.probeTokens, model: model)
        do {
            _ = try await client.respond(request)
        } catch let failure as ClaudeFailure {
            throw Self.translate(failure)
        }
        return nil
    }

    static func translate(_ failure: ClaudeFailure) -> any Error {
        switch failure {
        case .httpError(let code): StatusFailure(status: code)
        case .rateLimited: StatusFailure(status: rateLimitedStatus)
        case .overloaded: StatusFailure(status: overloadedStatus)
        case .invalidResponse, .decodingFailed, .streamInterrupted: ShapeFailure()
        case .notConnected: failure
        }
    }

    private struct HeldKey: KeyPort {
        let key: ClaudeKey

        func claudeKey() async -> ClaudeKey? { key }
    }

    private struct StatusFailure: StatusErrorPort {
        let status: Int
    }

    private struct ShapeFailure: ShapeErrorPort {}
}
