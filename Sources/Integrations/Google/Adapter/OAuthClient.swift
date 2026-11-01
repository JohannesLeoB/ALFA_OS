import Assistant
import Core
import Foundation
import Hub
import Synchronization

struct OAuthClient: TokenRefreshPort {
    static let authorizationEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
    static let tokenEndpoint = "https://oauth2.googleapis.com/token"
    static let revocationEndpoint = "https://oauth2.googleapis.com/revoke"
    static let invalidTokenStatus = 400

    let config: ClientConfig
    let http: any HttpPort

    func authorization(scopes: [OAuthScope], redirectURI: String, loginHint: String? = nil) throws -> AuthorizationParams {
        let pkce = try PkceChallenge.generate(unavailable: SignInFailure.randomUnavailable)
        let state = UUID().uuidString
        var query = [
            URLQueryItem(name: "client_id", value: config.clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes.map(\.rawValue).joined(separator: " ")),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: PkceChallenge.method),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "select_account consent"),
        ]
        if let loginHint, !loginHint.isEmpty { query.append(URLQueryItem(name: "login_hint", value: loginHint)) }
        let url = try RequestClient.url(Self.authorizationEndpoint, query: query)
        return AuthorizationParams(url: url, pkce: pkce, state: state, scopes: scopes)
    }

    func code(from redirect: URL, expectedState: String) -> String? {
        guard let items = URLComponents(url: redirect, resolvingAgainstBaseURL: false)?.queryItems,
              let code = items.first(where: { $0.name == "code" })?.value,
              items.first(where: { $0.name == "state" })?.value == expectedState else { return nil }
        return code
    }

    func exchange(code: String, verifier: String, redirectURI: String) async throws -> OAuthToken {
        try await post([
            "client_id": config.clientID,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI,
        ])
    }

    func refresh(refreshToken: String) async throws -> OAuthToken {
        try await post([
            "client_id": config.clientID,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token",
        ])
    }

    func revoke(token: String) async throws {
        var request = URLRequest(url: try RequestClient.url(Self.revocationEndpoint))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = FormBodyEngine.encode(["token": token])
        let (data, response) = try await http.data(for: request)
        guard let status = (response as? HTTPURLResponse)?.statusCode else { throw GoogleFailure.invalidResponse }
        guard (200...299).contains(status) || status == Self.invalidTokenStatus else {
            throw GoogleFailure.api(.oauth, APIFault(status: status, data: data))
        }
    }

    private func post(_ parameters: [String: String]) async throws -> OAuthToken {
        var request = URLRequest(url: try RequestClient.url(Self.tokenEndpoint))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = parameters
        if !config.clientSecret.isEmpty { form["client_secret"] = config.clientSecret }
        request.httpBody = FormBodyEngine.encode(form)
        let (data, response) = try await http.data(for: request)
        guard let status = (response as? HTTPURLResponse)?.statusCode else { throw GoogleFailure.invalidResponse }
        guard (200...299).contains(status) else { throw GoogleFailure.api(.oauth, APIFault(status: status, data: data)) }
        guard let token = try? JSONDecoder().decode(OAuthToken.self, from: data) else { throw GoogleFailure.decodingFailed }
        return token
    }
}

public final class OAuthLoopback: RedirectPort, Sendable {
    static let host = "127.0.0.1"

    private let server: LoopbackServer

    public init(acceptedPage: String, unreadablePage: String) {
        server = LoopbackServer(host: Self.host, queueLabel: "google.oauth.loopback", acceptedPage: acceptedPage,
                                unreadablePage: unreadablePage, startupFailure: SignInFailure.loopbackStartupFailed,
                                cancelledFailure: SignInFailure.loopbackCancelled)
    }

    public func start() async throws -> String {
        try await server.start()
    }

    public func awaitRedirect() async throws -> URL {
        try await server.awaitRedirect()
    }

    public func stop() {
        server.stop()
    }

    static func redirectURL(from request: String, port: UInt16) -> URL? {
        LoopbackServer.redirectURL(from: request, port: port, host: host)
    }
}

struct SignInClient: SignInPort {
    let oauth: OAuthClient
    let openBrowser: @Sendable (URL) async -> Bool
    let makeRedirect: @Sendable () -> any RedirectPort
    let clock: @Sendable () -> Date

    init(oauth: OAuthClient,
         openBrowser: @escaping @Sendable (URL) async -> Bool,
         makeRedirect: @escaping @Sendable () -> any RedirectPort,
         clock: @escaping @Sendable () -> Date) {
        self.oauth = oauth
        self.openBrowser = openBrowser
        self.makeRedirect = makeRedirect
        self.clock = clock
    }

    func signIn(_ inlet: Inlet, input: [Field.ID: String]) async throws -> Grant {
        let server = makeRedirect()
        do {
            let redirectURI = try await server.start()
            let params = try oauth.authorization(
                scopes: ScopeEngine.scopes(for: inlet.capabilities), redirectURI: redirectURI, loginHint: input[Input.expectedAccountKey])
            guard await openBrowser(params.url) else { throw SignInFailure.browserFailed }
            let callback = try await server.awaitRedirect()
            server.stop()
            guard let code = oauth.code(from: callback, expectedState: params.state) else {
                throw SignInFailure.redirectStateMismatch
            }
            let token = try await oauth.exchange(code: code, verifier: params.pkce.verifier, redirectURI: redirectURI)
            return StoredToken(token: token, previousRefresh: nil, now: clock()).grant
        } catch {
            server.stop()
            throw error
        }
    }

    func renew(_ grant: Grant) async throws -> Grant {
        let state = try StoredToken(grant: grant)
        guard let refreshToken = state.refreshToken else { throw SignInFailure.refreshUnavailable }
        let token = try await oauth.refresh(refreshToken: refreshToken)
        return StoredToken(token: token, previousRefresh: refreshToken, now: clock()).grant
    }

    func signOut(_ inlet: Inlet) async throws {}

    func revoke(_ grant: Grant) async throws {
        let state = try StoredToken(grant: grant)
        try await oauth.revoke(token: state.refreshToken ?? state.accessToken)
    }
}

final class AccessTokenClient: AccessTokenPort, Sendable {
    static let expirySkew: TimeInterval = 60
    static let chainLimit = 8

    private let state: Mutex<StoredToken>
    private let refresher: any TokenRefreshPort
    private let clock: @Sendable () -> Date
    private let renewal: GrantRenewal
    private let flight: RefreshFlight<StoredToken>

    init(state: StoredToken, refresher: any TokenRefreshPort, clock: @escaping @Sendable () -> Date,
         renewal: GrantRenewal = .ignoring, flight: RefreshFlight<StoredToken> = RefreshFlight()) {
        self.state = Mutex(state)
        self.refresher = refresher
        self.clock = clock
        self.renewal = renewal
        self.flight = flight
    }

    func validAccessToken() async throws -> String {
        var current = state.withLock { $0 }
        if fresh(current) { return current.accessToken }
        current = newest(current)
        state.withLock { $0 = current }
        if fresh(current) { return current.accessToken }
        guard let refreshToken = current.refreshToken else {
            if Self.isRejection(SignInFailure.refreshUnavailable) { renewal.failed(SignInFailure.refreshUnavailable) }
            throw SignInFailure.refreshUnavailable
        }
        let renewed = try await flight.run(refreshToken, reuse: { [self] in fresh($0) }) { [self] in try await refresh(refreshToken) }
        state.withLock { $0 = renewed }
        return renewed.accessToken
    }

    private func newest(_ start: StoredToken) -> StoredToken {
        var current = start
        for _ in 0..<Self.chainLimit {
            guard let key = current.refreshToken, let next = flight.recent(key), next != current else { break }
            current = next
        }
        return current
    }

    private func fresh(_ token: StoredToken) -> Bool {
        token.expiresAt.timeIntervalSince(clock()) > Self.expirySkew
    }

    private func refresh(_ refreshToken: String) async throws -> StoredToken {
        do {
            let token = try await refresher.refresh(refreshToken: refreshToken)
            let renewed = StoredToken(token: token, previousRefresh: refreshToken, now: clock())
            renewal.renewed(renewed.grant)
            return renewed
        } catch {
            if Self.isRejection(error) { renewal.failed(error) }
            throw error
        }
    }

    static func isRejection(_ error: any Error) -> Bool {
        switch error {
        case is GoogleFailure, SignInFailure.refreshUnavailable: GoogleFailureEngine.classify(error).kind == .signIn
        default: false
        }
    }
}

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
