import Assistant
import Foundation
import Hub

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

struct ProbeClient: ProbePort {
    static let grantKey = "hint.google.grant"
    static let tokenKey = "hint.google.token"
    static let userInfoKey = "hint.google.userinfo"
    static let labelsKey = "hint.google.labels"
    static let unauthorizedDetail = "HTTP 401"

    let oauth: OAuthClient
    let clock: @Sendable () -> Date
    let policy: RequestPolicy

    func probe(_ inlet: Inlet, _ grant: Grant) async throws -> ProbeResult {
        let state: StoredToken
        do {
            state = try StoredToken(grant: grant)
        } catch {
            return ProbeResult(account: inlet.id, rejection: Hint(text: Self.grantKey, detail: String(describing: error)))
        }
        let tokens = AccessTokenClient(state: state, refresher: oauth, clock: clock)
        let token: String
        do {
            token = try await tokens.validAccessToken()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return ProbeResult(account: inlet.id, rejection: Self.hint(Self.tokenKey, error))
        }
        let email: String
        do {
            email = try await UserInfoClient(http: oauth.http).fetchUserInfo(accessToken: token).email
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return ProbeResult(account: inlet.id, rejection: Self.hint(Self.userInfoKey, error))
        }
        let gmail = GmailClient(requests: RequestClient(http: oauth.http, tokens: tokens, product: .gmail), policy: policy)
        do {
            _ = try await gmail.listLabels()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return ProbeResult(account: email, rejection: Self.hint(Self.labelsKey, error))
        }
        return ProbeResult(account: email)
    }

    static func hint(_ text: String, _ error: any Error) -> Hint {
        let classification = FailureEngine.classify(error)
        return Hint(text: text, detail: detail(of: error, classification), kind: classification.kind,
                    original: classification.original)
    }

    private static func detail(of error: any Error, _ classification: Classification) -> String {
        switch error {
        case GoogleFailure.api: classification.detail ?? "HTTP \(classification.original.status ?? 0)"
        case GoogleFailure.notConnected: unauthorizedDetail
        default: String(describing: error)
        }
    }
}
