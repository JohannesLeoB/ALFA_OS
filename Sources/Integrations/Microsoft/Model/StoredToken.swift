import CryptoKit
import Foundation
import Hub

struct StoredToken: Equatable, Sendable {
    static let accessKey = "accessToken"
    static let refreshKey = "refreshToken"
    static let expiryKey = "expiresAt"
    static let addressKey = "address"
    static let nameKey = "displayName"
    static let defaultLifetime = 3600

    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date
    var identity: MailIdentity

    init(accessToken: String, refreshToken: String?, expiresAt: Date, identity: MailIdentity) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.identity = identity
    }

    init(grant: Grant) throws {
        func value(_ key: String) throws -> String {
            guard let text = grant.values[key], !text.isEmpty else { throw SignInFailure.grantIncomplete(key) }
            return text
        }
        guard let expiry = TimeInterval(try value(Self.expiryKey)) else { throw SignInFailure.grantIncomplete(Self.expiryKey) }
        self.init(accessToken: try value(Self.accessKey), refreshToken: grant.values[Self.refreshKey],
                  expiresAt: Date(timeIntervalSince1970: expiry),
                  identity: MailIdentity(address: try value(Self.addressKey), name: grant.values[Self.nameKey] ?? ""))
    }

    init(token: OAuthToken, identity: MailIdentity, previousRefresh: String?, now: Date) {
        self.init(accessToken: token.accessToken, refreshToken: token.refreshToken ?? previousRefresh,
                  expiresAt: now.addingTimeInterval(TimeInterval(token.expiresIn ?? Self.defaultLifetime)),
                  identity: identity)
    }

    var grant: Grant {
        var values = [Self.accessKey: accessToken, Self.expiryKey: String(expiresAt.timeIntervalSince1970),
                      Self.addressKey: identity.address, Self.nameKey: identity.name]
        if let refreshToken { values[Self.refreshKey] = refreshToken }
        return Grant(values: values)
    }
}

struct AuthorizationParams: Sendable {
    let url: URL
    let pkce: PkceChallenge
    let state: String
}

struct MailIdentity: Equatable, Sendable {
    var address: String
    var name: String
}

enum MicrosoftFailure: Error, Equatable, Sendable {
    case invalidResponse
    case invalidEndpoint
    case decodingFailed
    case identityMissing
    case api(OAuthFault)
}

struct OAuthFault: Equatable, Sendable {
    let status: Int
    let reason: String?
    let message: String?

    init(status: Int, reason: String? = nil, message: String? = nil) {
        self.status = status
        self.reason = reason
        self.message = message
    }

    init(status: Int, data: Data) {
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        self.init(status: status, reason: object?["error"] as? String, message: object?["error_description"] as? String)
    }

    var isServerFault: Bool { status == 429 || (500...599).contains(status) }
}

enum OAuthScope: String, CaseIterable, Sendable {
    case imap = "https://outlook.office.com/IMAP.AccessAsUser.All"
    case smtp = "https://outlook.office.com/SMTP.Send"
    case offlineAccess = "offline_access"
    case openid
    case profile
    case email
}

struct OAuthToken: Decodable, Equatable, Sendable {
    var accessToken: String
    var expiresIn: Int?
    var refreshToken: String?
    var idToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
    }
}

struct PkceChallenge: Sendable {
    static let method = "S256"
    private static let verifierBytes = 64

    let verifier: String
    let challenge: String

    static func generate() throws -> PkceChallenge {
        var bytes = [UInt8](repeating: 0, count: verifierBytes)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw SignInFailure.randomUnavailable }
        let verifier = URLSafeEngine.encodeURL(Data(bytes))
        let challenge = URLSafeEngine.encodeURL(Data(SHA256.hash(data: Data(verifier.utf8))))
        return PkceChallenge(verifier: verifier, challenge: challenge)
    }
}

enum SignInFailure: Error, Equatable, Sendable {
    case clientConfigMissing(String)
    case clientConfigInvalid(String)
    case grantIncomplete(String)
    case refreshUnavailable
    case redirectStateMismatch
    case loopbackStartupFailed
    case loopbackCancelled
    case browserFailed
    case randomUnavailable
}
