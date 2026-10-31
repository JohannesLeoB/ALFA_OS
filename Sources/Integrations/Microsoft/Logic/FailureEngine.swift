import Foundation
import Hub

enum FailureEngine {
    static let provider = "oauth"

    static func classify(_ error: any Error) -> Classification? {
        switch error {
        case MicrosoftFailure.api(let fault): oauth(fault)
        case SignInFailure.refreshUnavailable:
            Classification(kind: .signIn, original: Original(provider: provider, code: "refreshUnavailable"))
        case MicrosoftFailure.identityMissing:
            Classification(kind: .rejected, original: Original(provider: provider, code: "identityMissing"))
        case is MicrosoftFailure: Classification.generic(error)
        default: nil
        }
    }

    static func isRejection(_ error: any Error) -> Bool {
        classify(error)?.kind == .signIn
    }

    private static func oauth(_ fault: OAuthFault) -> Classification {
        let kind: FailureKind
        switch fault.reason {
        case "invalid_grant", "invalid_client", "unauthorized_client", "interaction_required", "consent_required",
             "login_required": kind = .signIn
        case "server_error", "temporarily_unavailable": kind = .transient
        case "invalid_request", "invalid_scope", "unsupported_grant_type", "access_denied": kind = .rejected
        default:
            if fault.isServerFault {
                kind = .transient
            } else if fault.status == 400 || fault.status == 401 {
                kind = .signIn
            } else {
                kind = .rejected
            }
        }
        return Classification(kind: kind, original: Original(
            provider: provider, status: fault.status, code: fault.reason, text: fault.message))
    }
}

enum Base64Engine {
    static func encodeURL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func decodeURL(_ text: String) -> Data? {
        var padded = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while padded.count % 4 != 0 { padded += "=" }
        return Data(base64Encoded: padded)
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
