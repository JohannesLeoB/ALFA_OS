import Foundation

/// The adapter for the Messages API. It sends with the key of the user and never reports the key.
public struct AnthropicClient: AIClient {
    /// The API version that the request header names.
    public static let apiVersion = "2023-06-01"
    /// The address of the API.
    public static let defaultBaseURL = URL(string: "https://api.anthropic.com/")!
    /// Seconds before one request gives up.
    public static let requestTimeout: TimeInterval = 120
    /// The waits before the first and the second retry. A retry happens at most twice.
    public static let overloadWaits: [TimeInterval] = [2, 4]
    /// The longest wait that the API may ask for before a retry. A longer one ends the call.
    public static let maxRateLimitWait: TimeInterval = 30

    private let transport: any HTTPTransport
    private let keyProvider: @Sendable () throws -> String?
    private let baseURL: URL
    private let sleeper: Sleeper

    /// - Parameters:
    ///   - keyProvider: Returns the key of the user. The app reads it from the keychain.
    ///   - baseURL: The address of the API. Tests point it to a test address.
    ///   - sleeper: Waits before a retry. Tests record the waits instead.
    public init(
        transport: any HTTPTransport,
        keyProvider: @escaping @Sendable () throws -> String?,
        baseURL: URL = AnthropicClient.defaultBaseURL,
        sleeper: @escaping Sleeper = Sleep.real
    ) {
        self.transport = transport
        self.keyProvider = keyProvider
        self.baseURL = baseURL
        self.sleeper = sleeper
    }

    public func complete(_ request: AIRequest) async throws -> AIResponse {
        let key = try readKey()
        var retries = 0
        while true {
            do {
                return try await send(request, key: key)
            } catch let error as AIError {
                guard retries < Self.overloadWaits.count,
                      let wait = Self.retryWait(after: error, attempt: retries) else {
                    throw error
                }
                retries += 1
                try await sleeper(wait)
            }
        }
    }

    private func send(_ request: AIRequest, key: String) async throws -> AIResponse {
        let urlRequest = try makeURLRequest(for: request, key: key)
        let (data, http) = try await perform(urlRequest, key: key)
        return try AnthropicWire.response(from: data, requestID: http.headerValue("request-id"))
    }

    /// Sends one request and returns the answer when its status is a success. Every failure is mapped to `AIError`.
    private func perform(_ urlRequest: URLRequest, key: String) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let http: HTTPURLResponse
        do {
            (data, http) = try await transport.send(urlRequest)
        } catch is CancellationError {
            throw AIError.cancelled
        } catch let error as URLError where error.code == .cancelled {
            throw AIError.cancelled
        } catch {
            throw AIError.network(Self.redact(String(describing: error), key: key))
        }

        guard (200..<300).contains(http.statusCode) else {
            throw AnthropicErrors.error(for: http, body: data, key: key)
        }
        return (data, http)
    }

    /// The models that the key may use, all pages in order. The same headers as the messages call; no body.
    /// Without a key nothing is sent.
    public func listModels() async throws -> [AIModelInfo] {
        let key = try readKey()
        var models: [AIModelInfo] = []
        var after: String?
        for _ in 0..<Self.maxModelPages {
            let page = try await modelPage(after: after, key: key)
            models += page.models
            guard page.hasMore, let last = page.lastID, !last.isEmpty else { break }
            after = last
        }
        return models
    }

    /// The most pages of models that one listing reads.
    static let maxModelPages = 10

    private struct ModelPage {
        let models: [AIModelInfo]
        let hasMore: Bool
        let lastID: String?
    }

    private func modelPage(after: String?, key: String) async throws -> ModelPage {
        guard var components = URLComponents(url: baseURL.appendingPathComponent("v1/models"), resolvingAgainstBaseURL: false) else {
            throw AIError.network("the address of the models list is not valid")
        }
        if let after {
            components.queryItems = [URLQueryItem(name: "after_id", value: after)]
        }
        guard let url = components.url else {
            throw AIError.network("the address of the models list is not valid")
        }
        var http = URLRequest(url: url)
        http.httpMethod = "GET"
        http.timeoutInterval = Self.requestTimeout
        http.setValue(key, forHTTPHeaderField: "x-api-key")
        http.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        let (data, _) = try await perform(http, key: key)
        guard let wire = try? JSONDecoder().decode(ModelsWire.self, from: data) else {
            throw AIError.decoding
        }
        let models = wire.data.map { AIModelInfo(id: $0.id, displayName: $0.displayName ?? $0.id) }
        return ModelPage(models: models, hasMore: wire.hasMore ?? false, lastID: wire.lastID)
    }

    /// The wait before a retry, or nil when the error is not retried. Only short rate limits and busy answers (529) are.
    static func retryWait(after error: AIError, attempt: Int) -> TimeInterval? {
        switch error {
        case let .rateLimited(retryAfter):
            guard let wait = retryAfter, wait >= 0, wait <= maxRateLimitWait else { return nil }
            return wait
        case .overloaded(status: 529):
            return overloadWaits[attempt]
        default:
            return nil
        }
    }

    /// The key of the user. A missing, blank or unreadable key stops the call before anything is sent.
    private func readKey() throws -> String {
        let stored: String?
        do {
            stored = try keyProvider()
        } catch {
            throw AIError.noKey
        }
        guard let key = stored?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty else {
            throw AIError.noKey
        }
        return key
    }

    /// The answer as it is written. The key is read before anything is sent; errors end the stream.
    /// A stream is not retried: the events already read would be sent twice.
    public func stream(_ request: AIRequest) -> AsyncThrowingStream<AIStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                await self.run(request, into: continuation)
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func run(_ request: AIRequest, into continuation: AsyncThrowingStream<AIStreamEvent, Error>.Continuation) async {
        var key = ""
        do {
            key = try readKey()
            let urlRequest = try makeURLRequest(for: request, key: key, stream: true)
            let lines = try await openStream(urlRequest, key: key)
            var reader = SSEReader()
            for try await line in lines {
                guard try deliver(reader.feed(line), key: key, to: continuation) else { return }
            }
            guard try deliver(reader.finish(), key: key, to: continuation) else { return }
            try Task.checkCancellation()
            continuation.finish()
        } catch is CancellationError {
            continuation.finish(throwing: AIError.cancelled)
        } catch let error as AIError {
            continuation.finish(throwing: Self.redacted(error, key: key))
        } catch {
            continuation.finish(throwing: AIError.network(Self.redact(String(describing: error), key: key)))
        }
    }

    /// Yields the events of the frames. Returns false after an error event, which ends the stream.
    private func deliver(
        _ frames: [SSEFrame],
        key: String,
        to continuation: AsyncThrowingStream<AIStreamEvent, Error>.Continuation
    ) throws -> Bool {
        for frame in frames {
            guard let event = AIStreamDecoder.event(from: frame) else { continue }
            if case let .error(error) = event {
                continuation.yield(.error(Self.redacted(error, key: key)))
                continuation.finish()
                return false
            }
            continuation.yield(event)
        }
        return true
    }

    /// Opens the stream. A failed status becomes the same error as on a plain call.
    private func openStream(_ urlRequest: URLRequest, key: String) async throws -> AsyncThrowingStream<String, Error> {
        do {
            return try await transport.stream(urlRequest)
        } catch let failure as HTTPStatusError {
            guard let http = HTTPURLResponse(
                url: urlRequest.url ?? baseURL,
                statusCode: failure.status,
                httpVersion: nil,
                headerFields: failure.headers
            ) else {
                throw AIError.network("HTTP status \(failure.status)")
            }
            throw AnthropicErrors.error(for: http, body: failure.body, key: key)
        } catch is CancellationError {
            throw AIError.cancelled
        } catch let error as URLError where error.code == .cancelled {
            throw AIError.cancelled
        } catch let error as AIError {
            throw error
        } catch {
            throw AIError.network(Self.redact(String(describing: error), key: key))
        }
    }

    private func makeURLRequest(for request: AIRequest, key: String, stream: Bool = false) throws -> URLRequest {
        var http = URLRequest(url: baseURL.appendingPathComponent("v1/messages"))
        http.httpMethod = "POST"
        http.timeoutInterval = Self.requestTimeout
        http.setValue(key, forHTTPHeaderField: "x-api-key")
        http.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        http.setValue("application/json", forHTTPHeaderField: "content-type")
        http.httpBody = try AnthropicWire.body(for: request, stream: stream)
        return http
    }

    /// The error with the key removed from its text.
    static func redacted(_ error: AIError, key: String) -> AIError {
        guard !key.isEmpty else { return error }
        switch error {
        case let .badRequest(message):
            return .badRequest(redact(message, key: key))
        case let .network(message):
            return .network(redact(message, key: key))
        case let .unusableAnswer(message):
            return .unusableAnswer(redact(message, key: key))
        default:
            return error
        }
    }

    /// Removes the key from a text that may come from a transport error.
    static func redact(_ text: String, key: String) -> String {
        text.replacingOccurrences(of: key, with: "[redacted]")
    }
}

extension HTTPURLResponse {
    /// Looks up a header without regard to upper or lower case.
    func headerValue(_ name: String) -> String? {
        let wanted = name.lowercased()
        for (key, value) in allHeaderFields {
            if let text = key as? String, text.lowercased() == wanted {
                return value as? String
            }
        }
        return nil
    }
}

/// One model of the platform: its name for the API and the name for the people who read it.
public struct AIModelInfo: Sendable, Equatable {
    public let id: String
    public let displayName: String

    public init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

/// The answer of the models listing, one page.
private struct ModelsWire: Decodable {
    let data: [Entry]
    let hasMore: Bool?
    let lastID: String?

    enum CodingKeys: String, CodingKey {
        case data
        case hasMore = "has_more"
        case lastID = "last_id"
    }

    struct Entry: Decodable {
        let id: String
        let displayName: String?

        enum CodingKeys: String, CodingKey {
            case id
            case displayName = "display_name"
        }
    }
}
