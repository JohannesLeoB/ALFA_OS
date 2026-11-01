import Assistant
import Foundation
import Hub
import Mail
import XCTest
@testable import Microsoft

private final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func with<R>(_ body: (inout Value) -> R) -> R {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}

private final class FakeHttp: HttpPort, @unchecked Sendable {
    typealias Responder = @Sendable (URLRequest) -> (Int, String)

    private let responder: Responder
    private let seen = Locked<[URLRequest]>([])

    init(_ responder: @escaping Responder = { _ in (200, "{}") }) {
        self.responder = responder
    }

    var requests: [URLRequest] { seen.with { $0 } }

    var bodies: [String] { requests.map { String(decoding: $0.httpBody ?? Data(), as: UTF8.self) } }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        seen.with { $0.append(request) }
        let (status, text) = responder(request)
        let response = HTTPURLResponse(url: request.url ?? URL(fileURLWithPath: "/"), statusCode: status, httpVersion: nil,
                                       headerFields: nil)
        return (Data(text.utf8), response ?? URLResponse())
    }

    func lines(for request: URLRequest) async throws -> (AsyncThrowingStream<String, any Error>, URLResponse) {
        throw URLError(.unsupportedURL)
    }
}

private final class FakeRedirect: RedirectPort, @unchecked Sendable {
    let stopped = Locked<Int>(0)
    let answer: @Sendable () -> URL

    init(answer: @escaping @Sendable () -> URL) {
        self.answer = answer
    }

    func start() async throws -> String { "http://localhost:9" }

    func awaitRedirect() async throws -> URL { answer() }

    func stop() {
        stopped.with { $0 += 1 }
    }
}

private let start = Date(timeIntervalSince1970: 1_000_000)
private let identity = MailIdentity(address: "me@outlook.com", name: "Me")

private func idToken(_ claims: [String: String]) -> String {
    let payload = try? JSONSerialization.data(withJSONObject: claims)
    return "e30." + URLSafeEngine.encodeURL(payload ?? Data()) + ".sig"
}

private func state(expiresIn: TimeInterval = 3600, refresh: String? = "refresh") -> StoredToken {
    StoredToken(accessToken: "access", refreshToken: refresh, expiresAt: start.addingTimeInterval(expiresIn), identity: identity)
}

private func inlet() -> Inlet {
    Inlet(id: "microsoft-1", provider: "microsoft", capabilities: [.mail], owner: .company, title: "offer.microsoft")
}

private func client(_ http: FakeHttp) -> OAuthClient {
    OAuthClient(registration: Registration(clientID: "client-id"), http: http)
}

private func query(_ url: URL) -> [String: String] {
    var result: [String: String] = [:]
    for item in URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? [] { result[item.name] = item.value }
    return result
}

private func directory() throws -> URL {
    let root = URL(fileURLWithPath: ProcessInfo.processInfo.environment["TMPDIR"] ?? NSTemporaryDirectory(), isDirectory: true)
    let url = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

final class MicrosoftTests: XCTestCase {
    func testRegistrationStoreReadsTheClientID() throws {
        let folder = try directory()
        try Data(#"{"clientID": " abc "}"#.utf8).write(to: folder.appendingPathComponent(RegistrationStore.fileName))
        XCTAssertEqual(try RegistrationStore(directory: folder).load(), Registration(clientID: "abc"))
    }

    func testRegistrationStoreRefusesMissingAndEmptyFiles() throws {
        let folder = try directory()
        XCTAssertThrowsError(try RegistrationStore(directory: folder).load()) { error in
            guard case SignInFailure.clientConfigMissing = error else { return XCTFail("\(error)") }
        }
        try Data(#"{"clientID": "  "}"#.utf8).write(to: folder.appendingPathComponent(RegistrationStore.fileName))
        XCTAssertThrowsError(try RegistrationStore(directory: folder).load()) { error in
            guard case SignInFailure.clientConfigInvalid = error else { return XCTFail("\(error)") }
        }
    }

    func testAuthorizationAsksForMailScopesWithPkceAndHint() throws {
        let params = try client(FakeHttp()).authorization(redirectURI: "http://localhost:5", loginHint: "me@outlook.com")
        let items = query(params.url)
        XCTAssertEqual(params.url.host, "login.microsoftonline.com")
        XCTAssertEqual(params.url.path, "/common/oauth2/v2.0/authorize")
        XCTAssertEqual(items["client_id"], "client-id")
        XCTAssertEqual(items["redirect_uri"], "http://localhost:5")
        XCTAssertEqual(items["response_type"], "code")
        XCTAssertEqual(items["code_challenge_method"], "S256")
        XCTAssertEqual(items["code_challenge"], params.pkce.challenge)
        XCTAssertEqual(items["state"], params.state)
        XCTAssertEqual(items["login_hint"], "me@outlook.com")
        XCTAssertEqual(items["prompt"], "select_account")
        let scopes = Set((items["scope"] ?? "").split(separator: " ").map(String.init))
        XCTAssertEqual(scopes, ["https://outlook.office.com/IMAP.AccessAsUser.All", "https://outlook.office.com/SMTP.Send",
                                "offline_access", "openid", "profile", "email"])
        XCTAssertNil(items["client_secret"])
    }

    func testAuthorizationOmitsAnEmptyHint() throws {
        XCTAssertNil(query(try client(FakeHttp()).authorization(redirectURI: "http://localhost:5", loginHint: "").url)["login_hint"])
    }

    func testPkceChallengeIsTheHashOfTheVerifier() throws {
        let pkce = try PkceChallenge.generate()
        XCTAssertGreaterThanOrEqual(pkce.verifier.count, 43)
        XCTAssertNotEqual(pkce.verifier, try PkceChallenge.generate().verifier)
        XCTAssertFalse(pkce.challenge.contains("="))
    }

    func testCodeNeedsTheExpectedState() {
        let oauth = client(FakeHttp())
        XCTAssertEqual(oauth.code(from: URL(string: "http://localhost:9/?code=c&state=s")!, expectedState: "s"), "c")
        XCTAssertNil(oauth.code(from: URL(string: "http://localhost:9/?code=c&state=x")!, expectedState: "s"))
        XCTAssertNil(oauth.code(from: URL(string: "http://localhost:9/?state=s")!, expectedState: "s"))
    }

    func testRedirectErrorIsReadOnlyWithTheExpectedState() {
        let oauth = client(FakeHttp())
        let denied = URL(string: "http://localhost:9/?error=access_denied&error_description=Admin%20approval&state=s")!
        XCTAssertEqual(oauth.fault(in: denied, expectedState: "s"),
                       OAuthFault(status: 400, reason: "access_denied", message: "Admin approval"))
        XCTAssertNil(oauth.fault(in: denied, expectedState: "other"))
        XCTAssertNil(oauth.fault(in: URL(string: "http://localhost:9/?code=c&state=s")!, expectedState: "s"))
    }

    func testExchangeSendsThePublicClientForm() async throws {
        let http = FakeHttp { _ in (200, #"{"access_token":"a","expires_in":10,"refresh_token":"r","id_token":"t"}"#) }
        let token = try await client(http).exchange(code: "c", verifier: "v", redirectURI: "http://localhost:5")
        XCTAssertEqual(token, OAuthToken(accessToken: "a", expiresIn: 10, refreshToken: "r", idToken: "t"))
        let request = try XCTUnwrap(http.requests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://login.microsoftonline.com/common/oauth2/v2.0/token")
        XCTAssertEqual(request.httpMethod, "POST")
        let body = try XCTUnwrap(http.bodies.first)
        for part in ["client_id=client-id", "code=c", "code_verifier=v", "grant_type=authorization_code",
                     "redirect_uri=http%3A%2F%2Flocalhost%3A5"] {
            XCTAssertTrue(body.contains(part), part)
        }
        XCTAssertFalse(body.contains("client_secret"))
    }

    func testRefreshAsksForTheMailScopes() async throws {
        let http = FakeHttp { _ in (200, #"{"access_token":"a"}"#) }
        _ = try await client(http).refresh(refreshToken: "r")
        let body = try XCTUnwrap(http.bodies.first)
        XCTAssertTrue(body.contains("grant_type=refresh_token"))
        XCTAssertTrue(body.contains("refresh_token=r"))
        XCTAssertTrue(body.contains("IMAP.AccessAsUser.All"))
    }

    func testTokenEndpointErrorsCarryTheReason() async {
        let http = FakeHttp { _ in (400, #"{"error":"invalid_grant","error_description":"AADSTS70008 expired"}"#) }
        do {
            _ = try await client(http).refresh(refreshToken: "r")
            XCTFail("expected a failure")
        } catch {
            XCTAssertEqual(error as? MicrosoftFailure,
                           .api(OAuthFault(status: 400, reason: "invalid_grant", message: "AADSTS70008 expired")))
        }
    }

    func testTokenEndpointRejectsAnUnreadableAnswer() async {
        let http = FakeHttp { _ in (200, "nope") }
        do {
            _ = try await client(http).refresh(refreshToken: "r")
            XCTFail("expected a failure")
        } catch {
            XCTAssertEqual(error as? MicrosoftFailure, .decodingFailed)
        }
    }

    func testIdentityComesFromTheEmailClaimThenFromThePreferredUsername() {
        XCTAssertEqual(IdentityParser.parse(idToken: idToken(["email": "a@outlook.com", "name": "Ann", "preferred_username": "x@y.z"])),
                       MailIdentity(address: "a@outlook.com", name: "Ann"))
        XCTAssertEqual(IdentityParser.parse(idToken: idToken(["preferred_username": "b@firma.de"])),
                       MailIdentity(address: "b@firma.de", name: "b@firma.de"))
        XCTAssertEqual(IdentityParser.parse(idToken: idToken(["email": "nobody", "preferred_username": "c@firma.de", "name": " "])),
                       MailIdentity(address: "c@firma.de", name: "c@firma.de"))
    }

    func testIdentityIsMissingWithoutAnAddressOrAReadableToken() {
        XCTAssertNil(IdentityParser.parse(idToken: idToken(["name": "Ann"])))
        XCTAssertNil(IdentityParser.parse(idToken: "garbage"))
        XCTAssertNil(IdentityParser.parse(idToken: "a.!!!.c"))
    }

    func testStoredTokenSurvivesAGrantRoundTrip() throws {
        let original = state()
        XCTAssertEqual(try StoredToken(grant: original.grant), original)
        XCTAssertNil(try StoredToken(grant: state(refresh: nil).grant).refreshToken)
    }

    func testIncompleteGrantsNameTheMissingKey() {
        XCTAssertThrowsError(try StoredToken(grant: Grant(values: [:]))) { error in
            XCTAssertEqual(error as? SignInFailure, .grantIncomplete(StoredToken.expiryKey))
        }
        var values = state().grant.values
        values[StoredToken.addressKey] = nil
        XCTAssertThrowsError(try StoredToken(grant: Grant(values: values))) { error in
            XCTAssertEqual(error as? SignInFailure, .grantIncomplete(StoredToken.addressKey))
        }
    }

    func testNewTokenKeepsTheOldRefreshTokenWhenNoneComesBack() {
        let token = OAuthToken(accessToken: "n", expiresIn: nil, refreshToken: nil, idToken: nil)
        let renewed = StoredToken(token: token, identity: identity, previousRefresh: "old", now: start)
        XCTAssertEqual(renewed.refreshToken, "old")
        XCTAssertEqual(renewed.expiresAt, start.addingTimeInterval(TimeInterval(StoredToken.defaultLifetime)))
    }

    func testMailTokenClientReusesAValidToken() async throws {
        let http = FakeHttp()
        let tokens = MailTokenClient(state: state(), refresher: client(http), clock: { start })
        let first = try await tokens.accessToken()
        XCTAssertEqual(first, "access")
        XCTAssertTrue(http.requests.isEmpty)
    }

    func testMailTokenClientRefreshesAnExpiringTokenAndReportsTheNewGrant() async throws {
        let http = FakeHttp { _ in (200, #"{"access_token":"fresh","expires_in":3600}"#) }
        let renewed = Locked<Grant?>(nil)
        let renewal = GrantRenewal(renewed: { grant in renewed.with { $0 = grant } }, failed: { _ in XCTFail("failed") })
        let tokens = MailTokenClient(state: state(expiresIn: 30), refresher: client(http), clock: { start }, renewal: renewal)
        let token = try await tokens.accessToken()
        XCTAssertEqual(token, "fresh")
        let grant = try XCTUnwrap(renewed.with { $0 })
        XCTAssertEqual(grant.values[StoredToken.accessKey], "fresh")
        XCTAssertEqual(grant.values[StoredToken.refreshKey], "refresh")
        XCTAssertEqual(grant.values[StoredToken.addressKey], "me@outlook.com")
    }

    func testMailTokenClientReportsARejectedRefresh() async {
        let http = FakeHttp { _ in (400, #"{"error":"invalid_grant"}"#) }
        let failed = Locked<Int>(0)
        let renewal = GrantRenewal(renewed: { _ in XCTFail("renewed") }, failed: { _ in failed.with { $0 += 1 } })
        let tokens = MailTokenClient(state: state(expiresIn: 0), refresher: client(http), clock: { start }, renewal: renewal)
        do {
            _ = try await tokens.accessToken()
            XCTFail("expected a failure")
        } catch {
            XCTAssertEqual(failed.with { $0 }, 1)
        }
    }

    func testMailTokenClientKeepsQuietOnATransientRefreshFailure() async {
        let http = FakeHttp { _ in (503, "") }
        let renewal = GrantRenewal(renewed: { _ in XCTFail("renewed") }, failed: { _ in XCTFail("failed") })
        let tokens = MailTokenClient(state: state(expiresIn: 0), refresher: client(http), clock: { start }, renewal: renewal)
        do {
            _ = try await tokens.accessToken()
            XCTFail("expected a failure")
        } catch {
            XCTAssertEqual(error as? MicrosoftFailure, .api(OAuthFault(status: 503)))
        }
    }

    func testMailTokenClientNeedsARefreshToken() async {
        let failed = Locked<Int>(0)
        let renewal = GrantRenewal(renewed: { _ in }, failed: { _ in failed.with { $0 += 1 } })
        let tokens = MailTokenClient(state: state(expiresIn: 0, refresh: nil), refresher: client(FakeHttp()), clock: { start },
                                     renewal: renewal)
        do {
            _ = try await tokens.accessToken()
            XCTFail("expected a failure")
        } catch {
            XCTAssertEqual(error as? SignInFailure, .refreshUnavailable)
            XCTAssertEqual(failed.with { $0 }, 1)
        }
    }

    private func signInClient(_ http: FakeHttp, browser: @escaping @Sendable (URL) async -> Bool,
                              redirect: @escaping @Sendable () -> any RedirectPort) -> SignInClient {
        SignInClient(oauth: client(http), openBrowser: browser, makeRedirect: redirect, clock: { start })
    }

    func testSignInRunsTheWholeFlowAndKeepsTheAddress() async throws {
        let token = idToken(["email": "me@outlook.com", "name": "Me"])
        let http = FakeHttp { _ in (200, #"{"access_token":"a","expires_in":3600,"refresh_token":"r","id_token":"\#(token)"}"#) }
        let opened = Locked<URL?>(nil)
        let redirect = FakeRedirect { URL(string: "http://localhost:9/?code=the-code&state=\(query(opened.with { $0 }!)["state"]!)")! }
        let signIn = signInClient(http, browser: { url in
            opened.with { $0 = url }
            return true
        }, redirect: { redirect })
        let grant = try await signIn.signIn(inlet(), input: [Input.expectedAccountKey: "me@outlook.com"])
        XCTAssertEqual(query(try XCTUnwrap(opened.with { $0 }))["login_hint"], "me@outlook.com")
        XCTAssertEqual(grant.values[StoredToken.accessKey], "a")
        XCTAssertEqual(grant.values[StoredToken.refreshKey], "r")
        XCTAssertEqual(grant.values[StoredToken.addressKey], "me@outlook.com")
        XCTAssertEqual(grant.values[StoredToken.nameKey], "Me")
        XCTAssertTrue(try XCTUnwrap(http.bodies.first).contains("code=the-code"))
        XCTAssertGreaterThanOrEqual(redirect.stopped.with { $0 }, 1)
    }

    func testSignInFailsWithoutAnIdentity() async {
        let http = FakeHttp { _ in (200, #"{"access_token":"a","refresh_token":"r"}"#) }
        let opened = Locked<URL?>(nil)
        let signIn = signInClient(http, browser: { url in
            opened.with { $0 = url }
            return true
        }, redirect: { FakeRedirect { URL(string: "http://localhost:9/?code=c&state=\(query(opened.with { $0 }!)["state"]!)")! } })
        do {
            _ = try await signIn.signIn(inlet(), input: [:])
            XCTFail("expected a failure")
        } catch {
            XCTAssertEqual(error as? MicrosoftFailure, .identityMissing)
        }
    }

    func testSignInSurfacesTheErrorOfTheRedirect() async {
        let opened = Locked<URL?>(nil)
        let http = FakeHttp()
        let signIn = signInClient(http, browser: { url in
            opened.with { $0 = url }
            return true
        }, redirect: {
            FakeRedirect {
                URL(string: "http://localhost:9/?error=access_denied&error_description=Needs%20admin&state=\(query(opened.with { $0 }!)["state"]!)")!
            }
        })
        do {
            _ = try await signIn.signIn(inlet(), input: [:])
            XCTFail("expected a failure")
        } catch {
            XCTAssertEqual(error as? MicrosoftFailure,
                           .api(OAuthFault(status: 400, reason: "access_denied", message: "Needs admin")))
            XCTAssertTrue(http.requests.isEmpty)
        }
    }

    func testSignInRefusesAWrongState() async {
        let signIn = signInClient(FakeHttp(), browser: { _ in true },
                                  redirect: { FakeRedirect { URL(string: "http://localhost:9/?code=c&state=wrong")! } })
        do {
            _ = try await signIn.signIn(inlet(), input: [:])
            XCTFail("expected a failure")
        } catch {
            XCTAssertEqual(error as? SignInFailure, .redirectStateMismatch)
        }
    }

    func testSignInStopsTheListenerWhenTheBrowserFails() async {
        let redirect = FakeRedirect { URL(fileURLWithPath: "/") }
        let signIn = signInClient(FakeHttp(), browser: { _ in false }, redirect: { redirect })
        do {
            _ = try await signIn.signIn(inlet(), input: [:])
            XCTFail("expected a failure")
        } catch {
            XCTAssertEqual(error as? SignInFailure, .browserFailed)
            XCTAssertEqual(redirect.stopped.with { $0 }, 1)
        }
    }

    func testRenewKeepsTheAddressAndTheRefreshToken() async throws {
        let http = FakeHttp { _ in (200, #"{"access_token":"b","expires_in":60}"#) }
        let signIn = signInClient(http, browser: { _ in true }, redirect: { FakeRedirect { URL(fileURLWithPath: "/") } })
        let grant = try await signIn.renew(state().grant)
        XCTAssertEqual(grant.values[StoredToken.accessKey], "b")
        XCTAssertEqual(grant.values[StoredToken.refreshKey], "refresh")
        XCTAssertEqual(grant.values[StoredToken.addressKey], "me@outlook.com")
        do {
            _ = try await signIn.renew(state(refresh: nil).grant)
            XCTFail("expected a failure")
        } catch {
            XCTAssertEqual(error as? SignInFailure, .refreshUnavailable)
        }
    }

    func testProbeRejectsAnIncompleteGrant() async throws {
        let probe = ProbeClient(oauth: client(FakeHttp()), mail: OAuthMailClient(), clock: { start })
        let result = try await probe.probe(inlet(), Grant(values: [:]))
        XCTAssertEqual(result.rejection?.text, ProbeClient.grantKey)
    }

    func testProbeRejectsARefusedRefresh() async throws {
        let http = FakeHttp { _ in (400, #"{"error":"invalid_grant","error_description":"gone"}"#) }
        let probe = ProbeClient(oauth: client(http), mail: OAuthMailClient(), clock: { start })
        let result = try await probe.probe(inlet(), state(expiresIn: 0).grant)
        XCTAssertEqual(result.account, "me@outlook.com")
        XCTAssertEqual(result.rejection?.text, ProbeClient.tokenKey)
        XCTAssertEqual(result.rejection?.kind, .signIn)
        XCTAssertEqual(result.rejection?.detail, "gone")
    }

    func testFailuresAreClassified() {
        func kind(_ error: any Error) -> FailureKind? { FailureEngine.classify(error)?.kind }
        XCTAssertEqual(kind(MicrosoftFailure.api(OAuthFault(status: 400, reason: "invalid_grant"))), .signIn)
        XCTAssertEqual(kind(MicrosoftFailure.api(OAuthFault(status: 400, reason: "interaction_required"))), .signIn)
        XCTAssertEqual(kind(MicrosoftFailure.api(OAuthFault(status: 400, reason: "access_denied"))), .rejected)
        XCTAssertEqual(kind(MicrosoftFailure.api(OAuthFault(status: 503))), .transient)
        XCTAssertEqual(kind(MicrosoftFailure.api(OAuthFault(status: 400))), .signIn)
        XCTAssertEqual(kind(MicrosoftFailure.api(OAuthFault(status: 404))), .rejected)
        XCTAssertEqual(kind(SignInFailure.refreshUnavailable), .signIn)
        XCTAssertEqual(kind(MicrosoftFailure.identityMissing), .rejected)
        XCTAssertEqual(kind(MicrosoftFailure.decodingFailed), .rejected)
        XCTAssertNil(FailureEngine.classify(URLError(.timedOut)))
        XCTAssertEqual(FailureEngine.classify(MicrosoftFailure.api(OAuthFault(status: 400, reason: "invalid_grant",
                                                                              message: "m")))?.detail, "m")
    }

    private func access(_ http: FakeHttp = FakeHttp()) -> OutlookAccess {
        OutlookAccess(registration: Registration(clientID: "client-id"), http: http, openBrowser: { _ in true },
                      makeRedirect: { FakeRedirect { URL(fileURLWithPath: "/") } }, clock: { start })
    }

    func testTheProviderOffersOneOutlookSignIn() {
        let provider = access()
        XCTAssertEqual(provider.id, "microsoft")
        XCTAssertEqual(provider.capabilities, [.mail])
        let offers = provider.offers(personal: .company)
        XCTAssertEqual(offers.count, 1)
        XCTAssertEqual(offers.first?.id, "offer.microsoft")
        XCTAssertEqual(offers.first?.title, "offer.microsoft")
        XCTAssertEqual(offers.first?.provider, "microsoft")
        XCTAssertEqual(offers.first?.capabilities, [.mail])
        XCTAssertEqual(offers.first?.way, .signIn)
    }

    func testTheProviderBuildsMailAndChangePortsOnly() throws {
        let provider = access()
        let grant = state().grant
        let transport = try provider.adapter((any MailTransportPort).self, for: inlet(), grant, renewal: .ignoring)
        XCTAssertTrue(String(describing: type(of: transport)).contains("IMAPSMTPClient"))
        _ = try provider.adapter((any ChangePort).self, for: inlet(), grant, renewal: .ignoring)
        XCTAssertThrowsError(try provider.adapter((any FilesPort).self, for: inlet(), grant, renewal: .ignoring))
        XCTAssertThrowsError(try provider.adapter((any MailTransportPort).self, for: inlet(), Grant(values: [:]),
                                                   renewal: .ignoring))
    }

    func testTheProviderClassifiesItsOwnFailuresAndMailFailures() {
        let provider = access()
        XCTAssertEqual(provider.classify(MicrosoftFailure.api(OAuthFault(status: 400, reason: "invalid_grant"))).kind, .signIn)
        XCTAssertEqual(provider.classify(MailFailure.connectionClosed).kind, .transient)
    }

    func testOutlookUsesTheMicrosoftServers() {
        XCTAssertEqual(OutlookAccess.endpoints, OAuthMailEndpoints(
            incomingHost: "outlook.office365.com", incomingPort: 993, outgoingHost: "smtp.office365.com", outgoingPort: 587,
            serverFilesSent: true))
    }

    func testLoopbackReadsOnlyTheRedirectRequest() {
        XCTAssertEqual(OAuthLoopback.redirectURL(from: "GET /?code=c&state=s HTTP/1.1\r\nHost: localhost\r\n\r\n", port: 7)?.absoluteString,
                       "http://localhost:7/?code=c&state=s")
        XCTAssertNil(OAuthLoopback.redirectURL(from: "GET /favicon.ico HTTP/1.1\r\n\r\n", port: 7))
        XCTAssertNil(OAuthLoopback.redirectURL(from: "POST /?code=c HTTP/1.1\r\n\r\n", port: 7))
    }

    func testFormBodyEscapesAndSortsValues() {
        XCTAssertEqual(String(decoding: FormBodyEngine.encode(["b": "x y", "a": "1&2"]), as: UTF8.self), "a=1%262&b=x%20y")
    }
}
