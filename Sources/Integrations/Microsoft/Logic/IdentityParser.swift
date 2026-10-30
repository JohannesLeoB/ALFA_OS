import Foundation

enum IdentityParser {
    static func parse(idToken: String) -> MailIdentity? {
        struct Claims: Decodable {
            let email: String?
            let preferredUsername: String?
            let name: String?

            enum CodingKeys: String, CodingKey {
                case email
                case preferredUsername = "preferred_username"
                case name
            }
        }
        let parts = idToken.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, let data = Base64Engine.decodeURL(String(parts[1])),
              let claims = try? JSONDecoder().decode(Claims.self, from: data) else { return nil }
        let candidates = [claims.email, claims.preferredUsername].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard let address = candidates.first(where: { $0.contains("@") }) else { return nil }
        let name = claims.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return MailIdentity(address: address, name: name.isEmpty ? address : name)
    }
}
