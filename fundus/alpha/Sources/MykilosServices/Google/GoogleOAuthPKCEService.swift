import Foundation
import CryptoKit

public struct GooglePKCEChallenge: Sendable {
    public let verifier: String
    public let challenge: String
    public let method: String

    public static func generate() -> GooglePKCEChallenge {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let verifier = Data(bytes).base64URLEncoded()
        let digest = SHA256.hash(data: Data(verifier.utf8))
        let challenge = Data(digest).base64URLEncoded()
        return GooglePKCEChallenge(verifier: verifier, challenge: challenge, method: "S256")
    }
}

public struct GoogleOAuthAuthorizationRequest: Sendable {
    public let url: URL
    public let pkce: GooglePKCEChallenge
    public let state: String
    public let scopes: [GoogleOAuthScope]
}

public struct GoogleOAuthPKCEService: Sendable {
    public let clientID: String
    public let clientSecret: String?
    public let redirectURI: String

    public init(clientID: String, clientSecret: String? = nil, redirectURI: String) {
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.redirectURI = redirectURI
    }

    private let authEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
    private let tokenEndpoint = "https://oauth2.googleapis.com/token"

    public func buildAuthorizationRequest(scopes: [GoogleOAuthScope]) -> GoogleOAuthAuthorizationRequest? {
        let pkce = GooglePKCEChallenge.generate()
        let state = UUID().uuidString

        var components = URLComponents(string: authEndpoint)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes.map(\.rawValue).joined(separator: " ")),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: pkce.method),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        guard let url = components?.url else { return nil }
        return GoogleOAuthAuthorizationRequest(url: url, pkce: pkce, state: state, scopes: scopes)
    }

    public struct RedirectResult: Sendable {
        public let code: String
        public let state: String
    }

    public func parseRedirect(_ url: URL, expectedState: String) -> RedirectResult? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              let state = components.queryItems?.first(where: { $0.name == "state" })?.value,
              state == expectedState else {
            return nil
        }
        return RedirectResult(code: code, state: state)
    }

    public func exchangeCodeForToken(
        code: String,
        codeVerifier: String,
        session: URLSession = .shared
    ) async throws -> GoogleOAuthTokenExchangeResponse {
        let request = try buildTokenExchangeRequest(code: code, codeVerifier: codeVerifier)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GoogleOAuthError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw GoogleOAuthError.api(GoogleAPIFault(status: http.statusCode, data: data))
        }
        do {
            return try JSONDecoder().decode(GoogleOAuthTokenExchangeResponse.self, from: data)
        } catch {
            throw GoogleOAuthError.decodingFailed
        }
    }

    private func buildTokenExchangeRequest(code: String, codeVerifier: String) throws -> URLRequest {
        guard let url = URL(string: tokenEndpoint) else {
            throw GoogleOAuthError.invalidEndpoint
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var parameters: [String: String] = [
            "client_id": clientID,
            "code": code,
            "code_verifier": codeVerifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI
        ]
        if let clientSecret, clientSecret.isEmpty == false {
            parameters["client_secret"] = clientSecret
        }
        request.httpBody = urlEncodedFormBody(parameters)
        return request
    }
}

public struct GoogleOAuthTokenExchangeResponse: Decodable, Sendable {
    public var accessToken: String
    public var expiresIn: Int?
    public var refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }
}

extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
