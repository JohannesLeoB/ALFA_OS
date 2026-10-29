import Assistant
import Foundation

struct OAuthClient: TokenRefreshPort {
    static let authorizationEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
    static let tokenEndpoint = "https://oauth2.googleapis.com/token"

    let config: ClientConfig
    let http: any HttpPort

    func authorization(scopes: [OAuthScope], redirectURI: String, loginHint: String? = nil) throws -> AuthorizationParams {
        let pkce = PkceChallenge.generate()
        let state = UUID().uuidString
        var query = [
            URLQueryItem(name: "client_id", value: config.clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes.map(\.rawValue).joined(separator: " ")),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: PkceChallenge.method),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "select_account consent"),
        ]
        if let loginHint, !loginHint.isEmpty { query.append(URLQueryItem(name: "login_hint", value: loginHint)) }
        let url = try RequestClient.url(Self.authorizationEndpoint, query: query)
        return AuthorizationParams(url: url, pkce: pkce, state: state, scopes: scopes)
    }

    func code(from redirect: URL, expectedState: String) -> String? {
        guard let items = URLComponents(url: redirect, resolvingAgainstBaseURL: false)?.queryItems,
              let code = items.first(where: { $0.name == "code" })?.value,
              items.first(where: { $0.name == "state" })?.value == expectedState else { return nil }
        return code
    }

    func exchange(code: String, verifier: String, redirectURI: String) async throws -> OAuthToken {
        try await post([
            "client_id": config.clientID,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI,
        ])
    }

    func refresh(refreshToken: String) async throws -> OAuthToken {
        try await post([
            "client_id": config.clientID,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token",
        ])
    }

    private func post(_ parameters: [String: String]) async throws -> OAuthToken {
        var request = URLRequest(url: try RequestClient.url(Self.tokenEndpoint))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = parameters
        if !config.clientSecret.isEmpty { form["client_secret"] = config.clientSecret }
        request.httpBody = FormBodyEngine.encode(form)
        let (data, response) = try await http.data(for: request)
        guard let status = (response as? HTTPURLResponse)?.statusCode else { throw GoogleFailure.invalidResponse }
        guard (200...299).contains(status) else { throw GoogleFailure.api(.oauth, APIFault(status: status, data: data)) }
        guard let token = try? JSONDecoder().decode(OAuthToken.self, from: data) else { throw GoogleFailure.decodingFailed }
        return token
    }
}

enum FormBodyEngine {
    static func encode(_ values: [String: String]) -> Data {
        Data(values.map { key, value in "\(escape(key))=\(escape(value))" }.sorted().joined(separator: "&").utf8)
    }

    private static func escape(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}
