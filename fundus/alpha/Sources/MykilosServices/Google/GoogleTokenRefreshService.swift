import Foundation

public protocol GoogleTokenRefreshing: Sendable {
    func refresh(refreshToken: String, clientID: String, clientSecret: String?) async throws -> GoogleOAuthTokenExchangeResponse
}

public struct GoogleTokenRefreshService: GoogleTokenRefreshing {
    private let tokenEndpoint = "https://oauth2.googleapis.com/token"
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func refresh(refreshToken: String, clientID: String, clientSecret: String? = nil) async throws -> GoogleOAuthTokenExchangeResponse {
        guard let url = URL(string: tokenEndpoint) else {
            throw GoogleOAuthError.invalidEndpoint
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var parameters: [String: String] = [
            "client_id": clientID,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        if let clientSecret, clientSecret.isEmpty == false {
            parameters["client_secret"] = clientSecret
        }
        request.httpBody = urlEncodedFormBody(parameters)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GoogleOAuthError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw GoogleOAuthError.httpError(http.statusCode) }

        do {
            return try JSONDecoder().decode(GoogleOAuthTokenExchangeResponse.self, from: data)
        } catch {
            throw GoogleOAuthError.decodingFailed
        }
    }
}
