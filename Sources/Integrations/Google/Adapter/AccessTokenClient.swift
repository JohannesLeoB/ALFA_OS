import Foundation
import Hub
import Synchronization

final class AccessTokenClient: AccessTokenPort, Sendable {
    static let expirySkew: TimeInterval = 60

    private let state: Mutex<TokenState>
    private let refresher: any TokenRefreshPort
    private let clock: @Sendable () -> Date
    private let renewal: GrantRenewal

    init(state: TokenState, refresher: any TokenRefreshPort, clock: @escaping @Sendable () -> Date,
         renewal: GrantRenewal = .ignoring) {
        self.state = Mutex(state)
        self.refresher = refresher
        self.clock = clock
        self.renewal = renewal
    }

    func validAccessToken() async throws -> String {
        let current = state.withLock { $0 }
        if current.expiresAt.timeIntervalSince(clock()) > Self.expirySkew { return current.accessToken }
        do {
            guard let refreshToken = current.refreshToken else { throw SignInFailure.refreshUnavailable }
            let token = try await refresher.refresh(refreshToken: refreshToken)
            let renewed = TokenState(token: token, previousRefresh: refreshToken, now: clock())
            state.withLock { $0 = renewed }
            renewal.renewed(renewed.grant)
            return renewed.accessToken
        } catch {
            if Self.isRejection(error) { renewal.failed(error) }
            throw error
        }
    }

    static func isRejection(_ error: any Error) -> Bool {
        switch error {
        case is GoogleFailure, SignInFailure.refreshUnavailable: FailureEngine.classify(error).kind == .signIn
        default: false
        }
    }
}
