import Foundation

/// The adapter for the Messages API. It sends with the key of the user and never reports the key.
public struct AnthropicClient: AIClient {
    /// The API version that the request header names.
    public static let apiVersion = "2023-06-01"
    /// The address of the API.
    public static let defaultBaseURL = URL(string: "https://api.anthropic.com/")!
    /// Seconds before one request gives up.
    public static let requestTimeout: TimeInterval = 120

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
        let urlRequest = try makeURLRequest(for: request, key: key)

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
            throw AIError.network("HTTP status \(http.statusCode)")
        }
        return try AnthropicWire.response(from: data, requestID: http.headerValue("request-id"))
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

    private func makeURLRequest(for request: AIRequest, key: String) throws -> URLRequest {
        var http = URLRequest(url: baseURL.appendingPathComponent("v1/messages"))
        http.httpMethod = "POST"
        http.timeoutInterval = Self.requestTimeout
        http.setValue(key, forHTTPHeaderField: "x-api-key")
        http.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        http.setValue("application/json", forHTTPHeaderField: "content-type")
        http.httpBody = try AnthropicWire.body(for: request)
        return http
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
