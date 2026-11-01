import Assistant
import Core
import Foundation
import Hub
import Mail
import Synchronization

struct OAuthClient: TokenRefreshPort {
    static let authorizationEndpoint = "https://login.microsoftonline.com/common/oauth2/v2.0/authorize"
    static let tokenEndpoint = "https://login.microsoftonline.com/common/oauth2/v2.0/token"
    static let scopeValue = OAuthScope.allCases.map(\.rawValue).joined(separator: " ")

    let registration: Registration
    let http: any HttpPort

    func authorization(redirectURI: String, loginHint: String? = nil) throws -> AuthorizationParams {
        let pkce = try PkceChallenge.generate(unavailable: SignInFailure.randomUnavailable)
        let state = UUID().uuidString
        var query = [
            URLQueryItem(name: "client_id", value: registration.clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "response_mode", value: "query"),
            URLQueryItem(name: "scope", value: Self.scopeValue),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: PkceChallenge.method),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "prompt", value: "select_account"),
        ]
        if let loginHint, !loginHint.isEmpty { query.append(URLQueryItem(name: "login_hint", value: loginHint)) }
        return AuthorizationParams(url: try Self.url(Self.authorizationEndpoint, query: query), pkce: pkce, state: state)
    }

    func code(from redirect: URL, expectedState: String) -> String? {
        guard let items = URLComponents(url: redirect, resolvingAgainstBaseURL: false)?.queryItems,
              items.first(where: { $0.name == "state" })?.value == expectedState else { return nil }
        return items.first(where: { $0.name == "code" })?.value
    }

    func fault(in redirect: URL, expectedState: String) -> OAuthFault? {
        guard let items = URLComponents(url: redirect, resolvingAgainstBaseURL: false)?.queryItems,
              items.first(where: { $0.name == "state" })?.value == expectedState,
              let reason = items.first(where: { $0.name == "error" })?.value else { return nil }
        return OAuthFault(status: 400, reason: reason, message: items.first(where: { $0.name == "error_description" })?.value)
    }

    func exchange(code: String, verifier: String, redirectURI: String) async throws -> OAuthToken {
        try await post([
            "client_id": registration.clientID,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI,
            "scope": Self.scopeValue,
        ])
    }

    func refresh(refreshToken: String) async throws -> OAuthToken {
        try await post([
            "client_id": registration.clientID,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token",
            "scope": Self.scopeValue,
        ])
    }

    static func url(_ base: String, query: [URLQueryItem] = []) throws -> URL {
        guard var components = URLComponents(string: base) else { throw MicrosoftFailure.invalidEndpoint }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw MicrosoftFailure.invalidEndpoint }
        return url
    }

    private func post(_ form: [String: String]) async throws -> OAuthToken {
        var request = URLRequest(url: try Self.url(Self.tokenEndpoint))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = FormBodyEngine.encode(form)
        let (data, response) = try await http.data(for: request)
        guard let status = (response as? HTTPURLResponse)?.statusCode else { throw MicrosoftFailure.invalidResponse }
        guard (200...299).contains(status) else { throw MicrosoftFailure.api(OAuthFault(status: status, data: data)) }
        guard let token = try? JSONDecoder().decode(OAuthToken.self, from: data) else { throw MicrosoftFailure.decodingFailed }
        return token
    }
}

final class MailTokenClient: MailTokenPort, Sendable {
    static let expirySkew: TimeInterval = 60

    private let state: Mutex<StoredToken>
    private let refresher: any TokenRefreshPort
    private let clock: @Sendable () -> Date
    private let renewal: GrantRenewal
    private let flight = SingleFlight<String>()

    init(state: StoredToken, refresher: any TokenRefreshPort, clock: @escaping @Sendable () -> Date,
         renewal: GrantRenewal = .ignoring) {
        self.state = Mutex(state)
        self.refresher = refresher
        self.clock = clock
        self.renewal = renewal
    }

    func accessToken() async throws -> String {
        let current = state.withLock { $0 }
        if current.expiresAt.timeIntervalSince(clock()) > Self.expirySkew { return current.accessToken }
        return try await flight.run { [self] in try await refreshed() }
    }

    private func refreshed() async throws -> String {
        let current = state.withLock { $0 }
        if current.expiresAt.timeIntervalSince(clock()) > Self.expirySkew { return current.accessToken }
        do {
            guard let refreshToken = current.refreshToken else { throw SignInFailure.refreshUnavailable }
            let token = try await refresher.refresh(refreshToken: refreshToken)
            let renewed = StoredToken(token: token, identity: current.identity, previousRefresh: refreshToken, now: clock())
            state.withLock { $0 = renewed }
            renewal.renewed(renewed.grant)
            return renewed.accessToken
        } catch {
            if MicrosoftFailureEngine.isRejection(error) { renewal.failed(error) }
            throw error
        }
    }
}

final class OAuthLoopback: RedirectPort, Sendable {
    static let host = "localhost"

    private let server: LoopbackServer

    init(acceptedPage: String, unreadablePage: String) {
        server = LoopbackServer(host: Self.host, queueLabel: "microsoft.oauth.loopback", acceptedPage: acceptedPage,
                                unreadablePage: unreadablePage, startupFailure: SignInFailure.loopbackStartupFailed,
                                cancelledFailure: SignInFailure.loopbackCancelled)
    }

    func start() async throws -> String {
        try await server.start()
    }

    func awaitRedirect() async throws -> URL {
        try await server.awaitRedirect()
    }

    func stop() {
        server.stop()
    }

    static func redirectURL(from request: String, port: UInt16) -> URL? {
        LoopbackServer.redirectURL(from: request, port: port, host: host)
    }
}

public struct OutlookAccess: ProviderPort {
    public static let providerID = "microsoft"
    static let endpoints = OAuthMailEndpoints(
        incomingHost: "outlook.office365.com", incomingPort: 993, outgoingHost: "smtp.office365.com", outgoingPort: 587,
        serverFilesSent: true)

    public let id: ID = OutlookAccess.providerID
    public let capabilities: Set<Capability> = [.mail]
    public let form: [Field] = []
    public let presets: [Preset] = []
    public let signIn: any SignInPort
    public let probe: any ProbePort
    private let oauth: OAuthClient
    private let mail = OAuthMailClient()
    private let clock: @Sendable () -> Date

    public init(registration: Registration, http: any HttpPort = URLSession.shared,
                openBrowser: @escaping @Sendable (URL) async -> Bool, acceptedPage: String, unreadablePage: String) {
        self.init(registration: registration, http: http, openBrowser: openBrowser,
                  makeRedirect: { OAuthLoopback(acceptedPage: acceptedPage, unreadablePage: unreadablePage) },
                  clock: { Date() })
    }

    init(registration: Registration, http: any HttpPort, openBrowser: @escaping @Sendable (URL) async -> Bool,
         makeRedirect: @escaping @Sendable () -> any RedirectPort, clock: @escaping @Sendable () -> Date) {
        let oauth = OAuthClient(registration: registration, http: http)
        self.oauth = oauth
        self.clock = clock
        signIn = SignInClient(oauth: oauth, openBrowser: openBrowser, makeRedirect: makeRedirect, clock: clock,
                              release: { [mail] inlet in mail.release(inlet) })
        probe = ProbeClient(oauth: oauth, mail: mail, clock: clock)
    }

    public func adapter<P>(_ port: P.Type, for inlet: Inlet, _ grant: Grant, renewal: GrantRenewal) throws -> P {
        let key = ObjectIdentifier(port)
        let wantsChanges = key == ObjectIdentifier((any ChangePort).self)
        guard wantsChanges || key == ObjectIdentifier((any MailTransportPort).self) else {
            throw HubFailure.capabilityMissing(inlet.id, inlet.capabilities.first ?? .mail)
        }
        let state = try StoredToken(grant: grant)
        let tokens = MailTokenClient(state: state, refresher: oauth, clock: clock, renewal: renewal)
        let made: Any = wantsChanges
            ? mail.changes(for: inlet.id, address: state.identity.address, name: state.identity.name,
                           endpoints: Self.endpoints, tokens: tokens)
            : mail.transport(for: inlet.id, address: state.identity.address, name: state.identity.name,
                             endpoints: Self.endpoints, tokens: tokens)
        guard let typed = made as? P else { throw HubFailure.capabilityMissing(inlet.id, .mail) }
        return typed
    }

    public func offers(personal: Owner) -> [Offer] {
        [Offer(id: "offer.microsoft", provider: id, title: "offer.microsoft", capabilities: [.mail], owner: personal,
               way: .signIn)]
    }

    public func classify(_ error: any Error) -> Classification {
        MicrosoftFailureEngine.classify(error) ?? mail.classify(error)
    }
}

struct ProbeClient: ProbePort {
    static let grantKey = "hint.microsoft.grant"
    static let tokenKey = "hint.microsoft.token"

    let oauth: OAuthClient
    let mail: OAuthMailClient
    let clock: @Sendable () -> Date

    func probe(_ inlet: Inlet, _ grant: Grant) async throws -> ProbeResult {
        let state: StoredToken
        do {
            state = try StoredToken(grant: grant)
        } catch {
            return ProbeResult(account: inlet.id, rejection: Hint(text: Self.grantKey, detail: String(describing: error)))
        }
        let tokens = MailTokenClient(state: state, refresher: oauth, clock: clock)
        let token: String
        do {
            token = try await tokens.accessToken()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return ProbeResult(account: state.identity.address, rejection: Self.hint(error))
        }
        return try await mail.probe(
            inlet: inlet.id, address: state.identity.address, name: state.identity.name, endpoints: OutlookAccess.endpoints,
            token: token)
    }

    static func hint(_ error: any Error) -> Hint {
        let classification = MicrosoftFailureEngine.classify(error) ?? Classification.generic(error)
        return Hint(text: tokenKey, detail: classification.detail ?? String(describing: error), kind: classification.kind,
                    original: classification.original)
    }
}

struct SignInClient: SignInPort {
    let oauth: OAuthClient
    let openBrowser: @Sendable (URL) async -> Bool
    let makeRedirect: @Sendable () -> any RedirectPort
    let clock: @Sendable () -> Date
    var release: @Sendable (Inlet.ID) -> Void = { _ in }

    func signIn(_ inlet: Inlet, input: [Field.ID: String]) async throws -> Grant {
        let server = makeRedirect()
        do {
            let redirectURI = try await server.start()
            let params = try oauth.authorization(redirectURI: redirectURI, loginHint: input[Input.expectedAccountKey])
            guard await openBrowser(params.url) else { throw SignInFailure.browserFailed }
            let callback = try await server.awaitRedirect()
            server.stop()
            if let fault = oauth.fault(in: callback, expectedState: params.state) { throw MicrosoftFailure.api(fault) }
            guard let code = oauth.code(from: callback, expectedState: params.state) else {
                throw SignInFailure.redirectStateMismatch
            }
            let token = try await oauth.exchange(code: code, verifier: params.pkce.verifier, redirectURI: redirectURI)
            guard let identity = token.idToken.flatMap(IdentityParser.parse) else { throw MicrosoftFailure.identityMissing }
            return StoredToken(token: token, identity: identity, previousRefresh: nil, now: clock()).grant
        } catch {
            server.stop()
            throw error
        }
    }

    func renew(_ grant: Grant) async throws -> Grant {
        let state = try StoredToken(grant: grant)
        guard let refreshToken = state.refreshToken else { throw SignInFailure.refreshUnavailable }
        let token = try await oauth.refresh(refreshToken: refreshToken)
        return StoredToken(token: token, identity: state.identity, previousRefresh: refreshToken, now: clock()).grant
    }

    func signOut(_ inlet: Inlet) async throws {
        release(inlet.id)
    }
}
