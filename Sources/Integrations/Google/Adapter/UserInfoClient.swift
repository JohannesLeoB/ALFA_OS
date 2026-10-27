import Assistant
import Foundation

struct UserInfoClient: Sendable {
    static let endpoint = "https://www.googleapis.com/oauth2/v2/userinfo"

    let http: any HttpPort

    func fetchUserInfo(accessToken: String) async throws -> UserInfo {
        var request = URLRequest(url: try RequestClient.url(Self.endpoint))
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await http.data(for: request)
        guard let status = (response as? HTTPURLResponse)?.statusCode else { throw GoogleFailure.invalidResponse }
        guard (200...299).contains(status) else { throw GoogleFailure.api(.oauth, APIFault(status: status, data: data)) }
        return try Self.parse(data)
    }

    static func parse(_ data: Data) throws -> UserInfo {
        struct Response: Decodable {
            let email: String
            let name: String?
        }
        guard let raw = try? JSONDecoder().decode(Response.self, from: data) else { throw GoogleFailure.decodingFailed }
        let name = raw.name?.trimmingCharacters(in: .whitespaces) ?? ""
        return UserInfo(email: raw.email, displayName: name.isEmpty ? raw.email : name)
    }
}

struct UserInfo: Equatable, Sendable {
    var email: String
    var displayName: String
}
