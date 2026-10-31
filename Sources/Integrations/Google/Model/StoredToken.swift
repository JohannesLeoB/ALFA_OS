import Foundation
import Hub

struct StoredToken: Equatable, Sendable {
    static let accessKey = "accessToken"
    static let refreshKey = "refreshToken"
    static let expiryKey = "expiresAt"
    static let defaultLifetime = 3600

    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date

    init(accessToken: String, refreshToken: String?, expiresAt: Date) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }

    init(grant: Grant) throws {
        guard let access = grant.values[Self.accessKey], !access.isEmpty else {
            throw SignInFailure.grantIncomplete(Self.accessKey)
        }
        guard let expiry = grant.values[Self.expiryKey].flatMap(TimeInterval.init) else {
            throw SignInFailure.grantIncomplete(Self.expiryKey)
        }
        self.init(accessToken: access, refreshToken: grant.values[Self.refreshKey],
                  expiresAt: Date(timeIntervalSince1970: expiry))
    }

    init(token: OAuthToken, previousRefresh: String?, now: Date) {
        self.init(accessToken: token.accessToken, refreshToken: token.refreshToken ?? previousRefresh,
                  expiresAt: now.addingTimeInterval(TimeInterval(token.expiresIn ?? Self.defaultLifetime)))
    }

    var grant: Grant {
        var values = [Self.accessKey: accessToken, Self.expiryKey: String(expiresAt.timeIntervalSince1970)]
        if let refreshToken { values[Self.refreshKey] = refreshToken }
        return Grant(values: values)
    }
}

struct OAuthToken: Decodable, Equatable, Sendable {
    var accessToken: String
    var expiresIn: Int?
    var refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }
}
