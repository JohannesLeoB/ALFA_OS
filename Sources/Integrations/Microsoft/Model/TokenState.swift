import Foundation
import Hub

struct TokenState: Equatable, Sendable {
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
