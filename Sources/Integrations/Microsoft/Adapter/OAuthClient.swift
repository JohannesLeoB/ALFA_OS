import Assistant
import Foundation

struct OAuthClient: TokenRefreshPort {
    static let authorizationEndpoint = "https://login.microsoftonline.com/common/oauth2/v2.0/authorize"
    static let tokenEndpoint = "https://login.microsoftonline.com/common/oauth2/v2.0/token"
    static let scopeValue = OAuthScope.allCases.map(\.rawValue).joined(separator: " ")

    let registration: Registration
    let http: any HttpPort

    func authorization(redirectURI: String, loginHint: String? = nil) throws -> AuthorizationParams {
        let pkce = PkceChallenge.generate()
        let state = UUID().uuidString
        var query = [
            URLQueryItem(name: "client_id", value: registration.clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "response_mode", value: "query"),
            URLQueryItem(name: "scope", value: Self.scopeValue),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: PkceChallenge.method),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "prompt", value: "select_account"),
        ]
        if let loginHint, !loginHint.isEmpty { query.append(URLQueryItem(name: "login_hint", value: loginHint)) }
        return AuthorizationParams(url: try Self.url(Self.authorizationEndpoint, query: query), pkce: pkce, state: state)
    }

    func code(from redirect: URL, expectedState: String) -> String? {
        guard let items = URLComponents(url: redirect, resolvingAgainstBaseURL: false)?.queryItems,
              items.first(where: { $0.name == "state" })?.value == expectedState else { return nil }
        return items.first(where: { $0.name == "code" })?.value
    }

    func fault(in redirect: URL, expectedState: String) -> OAuthFault? {
        guard let items = URLComponents(url: redirect, resolvingAgainstBaseURL: false)?.queryItems,
              items.first(where: { $0.name == "state" })?.value == expectedState,
              let reason = items.first(where: { $0.name == "error" })?.value else { return nil }
        return OAuthFault(status: 400, reason: reason, message: items.first(where: { $0.name == "error_description" })?.value)
    }

    func exchange(code: String, verifier: String, redirectURI: String) async throws -> OAuthToken {
        try await post([
            "client_id": registration.clientID,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI,
            "scope": Self.scopeValue,
        ])
    }

    func refresh(refreshToken: String) async throws -> OAuthToken {
        try await post([
            "client_id": registration.clientID,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token",
            "scope": Self.scopeValue,
        ])
    }

    static func url(_ base: String, query: [URLQueryItem] = []) throws -> URL {
        guard var components = URLComponents(string: base) else { throw MicrosoftFailure.invalidEndpoint }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw MicrosoftFailure.invalidEndpoint }
        return url
    }

    private func post(_ form: [String: String]) async throws -> OAuthToken {
        var request = URLRequest(url: try Self.url(Self.tokenEndpoint))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = FormBodyEngine.encode(form)
        let (data, response) = try await http.data(for: request)
        guard let status = (response as? HTTPURLResponse)?.statusCode else { throw MicrosoftFailure.invalidResponse }
        guard (200...299).contains(status) else { throw MicrosoftFailure.api(OAuthFault(status: status, data: data)) }
        guard let token = try? JSONDecoder().decode(OAuthToken.self, from: data) else { throw MicrosoftFailure.decodingFailed }
        return token
    }
}
