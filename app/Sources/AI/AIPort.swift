import Foundation

/// The port of the assistant. The app and the tests use this; the Messages API is one adapter.
public protocol AIClient: Sendable {
    func complete(_ request: AIRequest) async throws -> AIResponse
}

/// The port of the network. A test replaces it with recorded answers.
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
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
}
