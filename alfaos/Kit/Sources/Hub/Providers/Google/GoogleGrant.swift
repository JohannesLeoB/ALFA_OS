import Foundation
import MykilosServices

struct GoogleTokenState: Equatable, Sendable {
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date

    static let accessKey = "accessToken"
    static let refreshKey = "refreshToken"
    static let expiryKey = "expiresAt"

    init(accessToken: String, refreshToken: String?, expiresAt: Date) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }

    init(grant: Grant) throws {
        guard let access = grant.values[Self.accessKey], !access.isEmpty else {
            throw GoogleProviderError.grantIncomplete(Self.accessKey)
        }
        guard let expiry = grant.values[Self.expiryKey].flatMap(TimeInterval.init) else {
            throw GoogleProviderError.grantIncomplete(Self.expiryKey)
        }
        self.init(accessToken: access, refreshToken: grant.values[Self.refreshKey],
                  expiresAt: Date(timeIntervalSince1970: expiry))
    }

    var grant: Grant {
        var values = [Self.accessKey: accessToken, Self.expiryKey: String(expiresAt.timeIntervalSince1970)]
        if let refreshToken { values[Self.refreshKey] = refreshToken }
        return Grant(values: values)
    }

    init(response: GoogleOAuthTokenExchangeResponse, previousRefresh: String?, now: Date) {
        self.init(accessToken: response.accessToken, refreshToken: response.refreshToken ?? previousRefresh,
                  expiresAt: now.addingTimeInterval(TimeInterval(response.expiresIn ?? 3600)))
    }
}

final class GoogleGrantTokenProvider: GoogleAccessTokenProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var state: GoogleTokenState
    private let config: GoogleClientConfig
    private let refresher: any GoogleTokenRefreshing
    private let clock: @Sendable () -> Date
    private let renewal: GrantRenewal

    init(state: GoogleTokenState, config: GoogleClientConfig, refresher: any GoogleTokenRefreshing,
         clock: @escaping @Sendable () -> Date, renewal: GrantRenewal = .ignoring) {
        self.state = state
        self.config = config
        self.refresher = refresher
        self.clock = clock
        self.renewal = renewal
    }

    func validAccessToken() async throws -> String {
        let current = lock.withLock { state }
        if current.expiresAt.timeIntervalSince(clock()) > 60 { return current.accessToken }
        do {
            guard let refreshToken = current.refreshToken else { throw GoogleProviderError.refreshUnavailable }
            let response = try await refresher.refresh(refreshToken: refreshToken, clientID: config.clientID,
                                                       clientSecret: config.clientSecret)
            let renewed = GoogleTokenState(response: response, previousRefresh: refreshToken, now: clock())
            lock.withLock { state = renewed }
            renewal.renewed(renewed.grant)
            return renewed.accessToken
        } catch {
            if Self.isRejection(error) { renewal.failed(error) }
            throw error
        }
    }

    static func isRejection(_ error: Error) -> Bool {
        switch error {
        case is GoogleOAuthError, GoogleProviderError.refreshUnavailable:
            GoogleFailure.classify(error).kind == .signIn
        default: false
        }
    }
}
