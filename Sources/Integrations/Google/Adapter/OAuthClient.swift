import Assistant
import Foundation
import Hub
import Network
import Synchronization

struct OAuthClient: TokenRefreshPort {
    static let authorizationEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
    static let tokenEndpoint = "https://oauth2.googleapis.com/token"
    static let revocationEndpoint = "https://oauth2.googleapis.com/revoke"
    static let invalidTokenStatus = 400

    let config: ClientConfig
    let http: any HttpPort

    func authorization(scopes: [OAuthScope], redirectURI: String, loginHint: String? = nil) throws -> AuthorizationParams {
        let pkce = try PkceChallenge.generate()
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
    static let startupTimeout: Duration = .seconds(2)
    static let readLimit = 8_192
    static let host = "127.0.0.1"

    private struct State {
        var listener: NWListener?
        var continuation: CheckedContinuation<URL, any Error>?
        var pending: URL?
    }

    private let queue = DispatchQueue(label: "google.oauth.loopback")
    private let state = Mutex(State())
    private let acceptedPage: String
    private let unreadablePage: String

    public init(acceptedPage: String, unreadablePage: String) {
        self.acceptedPage = acceptedPage
        self.unreadablePage = unreadablePage
    }

    public func start() async throws -> String {
        let listener = try NWListener(using: .tcp, on: .any)
        let startup = Startup()
        listener.newConnectionHandler = { [weak self, weak listener] connection in
            guard let port = listener?.port?.rawValue else { return }
            self?.handle(connection, port: port)
        }
        listener.stateUpdateHandler = { [weak self, weak listener] newState in
            switch newState {
            case .ready:
                guard let port = listener?.port?.rawValue else {
                    startup.complete(.failure(SignInFailure.loopbackStartupFailed))
                    return
                }
                startup.complete(.success(port))
            case .failed:
                startup.complete(.failure(SignInFailure.loopbackStartupFailed))
                self?.stop()
            default:
                break
            }
        }
        state.withLock { $0.listener = listener }
        listener.start(queue: queue)
        let port: UInt16
        do {
            port = try await startup.wait(timeout: Self.startupTimeout)
        } catch {
            stop()
            throw error
        }
        return "http://\(Self.host):\(port)"
    }

    public func awaitRedirect() async throws -> URL {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let ready = state.withLock { state -> Result<URL, any Error>? in
                    if let pending = state.pending {
                        state.pending = nil
                        return .success(pending)
                    }
                    if Task.isCancelled { return .failure(SignInFailure.loopbackCancelled) }
                    state.continuation = continuation
                    return nil
                }
                if let ready { continuation.resume(with: ready) }
            }
        } onCancel: {
            stop()
        }
    }

    public func stop() {
        let (listener, continuation) = state.withLock { state -> (NWListener?, CheckedContinuation<URL, any Error>?) in
            let taken = (state.listener, state.continuation)
            state.listener = nil
            state.continuation = nil
            return taken
        }
        listener?.cancel()
        continuation?.resume(throwing: SignInFailure.loopbackCancelled)
    }

    private func handle(_ connection: NWConnection, port: UInt16) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: Self.readLimit) { [weak self] data, _, _, _ in
            guard let self else { return }
            guard let data, let request = String(data: data, encoding: .utf8),
                  let url = Self.redirectURL(from: request, port: port) else {
                respond(unreadablePage, status: "400 Bad Request", on: connection)
                return
            }
            respond(acceptedPage, status: "200 OK", on: connection)
            let continuation = state.withLock { state -> CheckedContinuation<URL, any Error>? in
                guard let waiting = state.continuation else {
                    state.pending = url
                    return nil
                }
                state.continuation = nil
                return waiting
            }
            continuation?.resume(returning: url)
        }
    }

    static func redirectURL(from request: String, port: UInt16) -> URL? {
        guard let firstLine = request.split(separator: "\r\n", maxSplits: 1).first else { return nil }
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2, parts[0] == "GET" else { return nil }
        let target = String(parts[1])
        guard target == "/" || target.hasPrefix("/?") else { return nil }
        return URL(string: "http://\(host):\(port)\(target)")
    }

    private func respond(_ body: String, status: String, on connection: NWConnection) {
        let head = "HTTP/1.1 \(status)\r\nContent-Type: text/html; charset=utf-8\r\n"
            + "Cache-Control: no-store\r\nContent-Security-Policy: default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; font-src data:\r\n"
            + "Content-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n"
        connection.send(content: Data((head + body).utf8), completion: .contentProcessed { _ in connection.cancel() })
    }
}

private final class Startup: Sendable {
    private struct State {
        var result: Result<UInt16, any Error>?
        var continuation: CheckedContinuation<UInt16, any Error>?
    }

    private let state = Mutex(State())

    func wait(timeout: Duration) async throws -> UInt16 {
        try await withCheckedThrowingContinuation { continuation in
            let ready = state.withLock { state -> Result<UInt16, any Error>? in
                if let result = state.result { return result }
                state.continuation = continuation
                return nil
            }
            if let ready {
                continuation.resume(with: ready)
                return
            }
            Task {
                try? await Task.sleep(for: timeout)
                complete(.failure(SignInFailure.loopbackStartupFailed))
            }
        }
    }

    func complete(_ result: Result<UInt16, any Error>) {
        let continuation = state.withLock { state -> CheckedContinuation<UInt16, any Error>? in
            guard state.result == nil else { return nil }
            state.result = result
            let waiting = state.continuation
            state.continuation = nil
            return waiting
        }
        continuation?.resume(with: result)
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

    private let state: Mutex<StoredToken>
    private let refresher: any TokenRefreshPort
    private let clock: @Sendable () -> Date
    private let renewal: GrantRenewal

    init(state: StoredToken, refresher: any TokenRefreshPort, clock: @escaping @Sendable () -> Date,
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
            let renewed = StoredToken(token: token, previousRefresh: refreshToken, now: clock())
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
