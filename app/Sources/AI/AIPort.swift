import Foundation

/// The port of the assistant. The app and the tests use this; the Messages API is one adapter.
public protocol AIClient: Sendable {
    func complete(_ request: AIRequest) async throws -> AIResponse
    /// The answer as it is written: events in order. Cancelling the reader ends the call; the events read so far stay.
    func stream(_ request: AIRequest) -> AsyncThrowingStream<AIStreamEvent, Error>
}

/// The port of the network. A test replaces it with recorded answers.
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
    /// The lines of a streamed answer. An answer that is not a success throws `HTTPStatusError` before any line.
    func stream(_ request: URLRequest) async throws -> AsyncThrowingStream<String, Error>
}

/// An answer of the network whose status is not a success. It carries the status, the headers and the body.
public struct HTTPStatusError: Error, Sendable, Equatable {
    public let status: Int
    public let headers: [String: String]
    public let body: Data

    public init(status: Int, headers: [String: String], body: Data) {
        self.status = status
        self.headers = headers
        self.body = body
    }
}

/// Waits for a number of seconds. The client asks for it before a retry; tests record instead of waiting.
public typealias Sleeper = @Sendable (TimeInterval) async throws -> Void

public enum Sleep {
    /// Waits in real time.
    public static let real: Sleeper = { seconds in
        try await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
    }
}

/// The transport of the app: a URL session without cache and without cookies.
public struct URLSessionTransport: HTTPTransport {
    private let session: URLSession

    public init(session: URLSession = URLSession(configuration: URLSessionTransport.configuration())) {
        self.session = session
    }

    /// The session configuration. Nothing is cached and no cookie is kept.
    public static func configuration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = AnthropicClient.requestTimeout
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        return configuration
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AIError.network("the answer is not HTTP")
        }
        return (data, http)
    }

    public func stream(_ request: URLRequest) async throws -> AsyncThrowingStream<String, Error> {
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AIError.network("the answer is not HTTP")
        }
        guard (200..<300).contains(http.statusCode) else {
            var body = Data()
            for try await byte in bytes {
                body.append(byte)
            }
            throw HTTPStatusError(status: http.statusCode, headers: Self.headers(of: http), body: body)
        }
        return AsyncThrowingStream { continuation in
            let reader = Task {
                do {
                    for try await line in bytes.lines {
                        continuation.yield(line)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in reader.cancel() }
        }
    }

    /// The headers of an answer as text pairs.
    static func headers(of http: HTTPURLResponse) -> [String: String] {
        var result: [String: String] = [:]
        for (key, value) in http.allHeaderFields {
            if let name = key as? String, let text = value as? String {
                result[name] = text
            }
        }
        return result
    }
}
