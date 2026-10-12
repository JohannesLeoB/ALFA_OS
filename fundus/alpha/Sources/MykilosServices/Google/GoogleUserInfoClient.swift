import Foundation
import MykilosKit

public protocol GoogleHTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: GoogleHTTPClient {}

public protocol GoogleUserInfoFetching: Sendable {
    func fetchUserInfo(accessToken: String) async throws -> GoogleUserInfo
}

public struct GoogleUserInfoClient: GoogleUserInfoFetching {
    private let httpClient: GoogleHTTPClient
    private let userInfoURL: URL

    public init(
        httpClient: GoogleHTTPClient = URLSession.shared,
        userInfoURL: URL = URL(string: "https://www.googleapis.com/oauth2/v2/userinfo")!
    ) {
        self.httpClient = httpClient
        self.userInfoURL = userInfoURL
    }

    public func fetchUserInfo(accessToken: String) async throws -> GoogleUserInfo {
        let request = Self.buildRequest(url: userInfoURL, accessToken: accessToken)
        let (data, response) = try await httpClient.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GoogleOAuthError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw GoogleOAuthError.httpError(http.statusCode) }
        return try Self.parseUserInfo(from: data)
    }

    static func buildRequest(url: URL, accessToken: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    static func parseUserInfo(from data: Data) throws -> GoogleUserInfo {
        do {
            let raw = try JSONDecoder().decode(GoogleUserInfoResponse.self, from: data)
            let displayName = raw.name?.trimmingCharacters(in: .whitespaces).isEmpty == false
                ? raw.name!
                : raw.email
            return GoogleUserInfo(email: raw.email, displayName: displayName)
        } catch let e as GoogleOAuthError {
            throw e
        } catch {
            throw GoogleOAuthError.decodingFailed
        }
    }
}

private struct GoogleUserInfoResponse: Decodable {
    let email: String
    let name: String?
}
