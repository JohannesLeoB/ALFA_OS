import Assistant
import Foundation

struct RequestClient: Sendable {
    let http: any HttpPort
    let tokens: any AccessTokenPort
    let product: Product

    static func url(_ base: String, query: [URLQueryItem] = []) throws -> URL {
        guard var components = URLComponents(string: base) else { throw GoogleFailure.invalidEndpoint }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw GoogleFailure.invalidEndpoint }
        return url
    }

    @discardableResult
    func send(_ url: URL, method: String = "GET", body: Data? = nil, contentType: String? = nil) async throws -> Data {
        let token: String
        do {
            token = try await tokens.validAccessToken()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw GoogleFailure.notConnected(product)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let contentType { request.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        request.httpBody = body
        let (data, response) = try await http.data(for: request)
        guard let status = (response as? HTTPURLResponse)?.statusCode else { throw GoogleFailure.invalidResponse }
        guard (200...299).contains(status) else { throw GoogleFailure.api(product, APIFault(status: status, data: data)) }
        return data
    }

    @discardableResult
    func send(_ url: URL, method: String, json: Any) async throws -> Data {
        let body = try JSONSerialization.data(withJSONObject: json)
        return try await send(url, method: method, body: body, contentType: "application/json")
    }
}
