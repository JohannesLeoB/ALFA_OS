import Assistant
import Core
import Foundation
import Hub
import Mail
import XCTest
@testable import Google

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

private struct Call: Equatable {
    var method: String
    var path: String
    var query: String
    var body: Data
    var authorization: String?
}

private final class FakeHttp: HttpPort, @unchecked Sendable {
    typealias Responder = @Sendable (Call) -> (Int, String)

    private let responder: Responder
    private let seen = Locked<[Call]>([])

    init(_ responder: @escaping Responder = { _ in (200, "{}") }) {
        self.responder = responder
    }

    var calls: [Call] { seen.with { $0 } }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let url = request.url
        let call = Call(method: request.httpMethod ?? "GET", path: url?.path ?? "", query: url?.query ?? "",
                        body: request.httpBody ?? Data(), authorization: request.value(forHTTPHeaderField: "Authorization"))
        seen.with { $0.append(call) }
        let (status, text) = responder(call)
        let response = HTTPURLResponse(url: url ?? URL(fileURLWithPath: "/"), statusCode: status, httpVersion: nil,
                                       headerFields: nil)
        return (Data(text.utf8), response ?? URLResponse())
    }

    func lines(for request: URLRequest) async throws -> (AsyncThrowingStream<String, any Error>, URLResponse) {
        throw URLError(.unsupportedURL)
    }
}

private struct StubTokens: AccessTokenPort {
    func validAccessToken() async throws -> String { "token" }
}

private struct RefusingTokens: AccessTokenPort {
    func validAccessToken() async throws -> String { throw SignInFailure.refreshUnavailable }
}

private struct StubRefresher: TokenRefreshPort {
    let result: Result<OAuthToken, GoogleFailure>
    let count = Locked<Int>(0)

    func refresh(refreshToken: String) async throws -> OAuthToken {
        count.with { $0 += 1 }
        return try result.get()
    }
}

private final class FakeRedirect: RedirectPort, @unchecked Sendable {
    let stopped = Locked<Int>(0)
    let target = Locked<URL?>(nil)
    let answer: @Sendable (URL) -> URL

    init(answer: @escaping @Sendable (URL) -> URL) {
        self.answer = answer
    }

    func start() async throws -> String { "http://127.0.0.1:9" }

    func awaitRedirect() async throws -> URL {
        answer(target.with { $0 } ?? URL(fileURLWithPath: "/"))
    }

    func stop() {
        stopped.with { $0 += 1 }
    }
}

private let grantStart = Date(timeIntervalSince1970: 1_000_000)

private func grant(expiresIn: TimeInterval = 3600, refresh: String? = "refresh") -> Grant {
    var values = [TokenState.accessKey: "access", TokenState.expiryKey: String(grantStart.addingTimeInterval(expiresIn).timeIntervalSince1970)]
    if let refresh { values[TokenState.refreshKey] = refresh }
    return Grant(values: values)
}

private func inlet(_ capabilities: Set<Capability>) -> Inlet {
    Inlet(id: "g", provider: "google", capabilities: capabilities, owner: .company, title: "g")
}

private let convention = OfferConvention(
    incomingFolderKeyword: "incoming", outgoingFolderKeyword: "outgoing", purchaseOrderFolderKeyword: "purchase",
    invoiceFolderKeyword: "invoice", offerFolderKeyword: "offer", orderFolderKeyword: "order",
    prefixes: ["AN": .offer, "AB": .orderConfirmation, "TR": .depositInvoice, "SR": .finalInvoice, "BE": .purchaseOrder],
    documentNumberPattern: #"(\d{4}-\d{3,4})(?!\d)"#, customerNumberPattern: #"Kd-(\d+)"#, versionPattern: #"_(v\d+)"#)

private let driveConfig = DriveConfig(projectsRoot: "root", forbiddenFolderIDs: ["locked"], offers: convention)

private func router(_ http: FakeHttp, redirect: @escaping @Sendable () -> any RedirectPort = { FakeRedirect { $0 } },
                    open: @escaping @Sendable (URL) async -> Bool = { _ in true }) -> AccessRouter {
    AccessRouter(config: ClientConfig(clientID: "id", clientSecret: "secret"), drive: driveConfig, http: http,
                 openBrowser: open, makeRedirect: redirect, signIn: nil, clock: { grantStart },
                 policy: RequestPolicy(firstDelay: .milliseconds(1)))
}

private func gmail(_ http: FakeHttp, policy: RequestPolicy = RequestPolicy(firstDelay: .milliseconds(1))) -> GmailClient {
    GmailClient(requests: RequestClient(http: http, tokens: StubTokens(), product: .gmail), policy: policy)
}

private func mailClient(_ http: FakeHttp) -> GmailMailClient {
    GmailMailClient(gmail: gmail(http))
}

private func drive(_ http: FakeHttp, forbidden: Set<String> = ["locked"]) -> DriveClient {
    DriveClient(requests: RequestClient(http: http, tokens: StubTokens(), product: .drive), forbiddenFolderIDs: forbidden)
}

private func json(_ call: Call) throws -> [String: Any] {
    try XCTUnwrap(JSONSerialization.jsonObject(with: call.body) as? [String: Any])
}

private func file(_ id: String, _ name: String, _ mime: String = "application/pdf") -> DriveFile {
    DriveFile(id: id, name: name, mimeType: mime, modifiedAt: nil, webViewLink: nil)
}

private struct FakeDrive: Google.DrivePort {
    let tree: [String: [DriveFile]]

    func listFolder(folderID: String) async throws -> [DriveFile] { tree[folderID] ?? [] }
    func fileName(of fileID: String) async throws -> String { fileID }
    func downloadContent(fileID: String) async throws -> Data { Data("raw \(fileID)".utf8) }
    func exportFile(fileID: String, exportMimeType: String) async throws -> Data { Data("\(exportMimeType) \(fileID)".utf8) }
    func findOrCreateSubfolder(parentID: String, name: String) async throws -> String { name }
    func uploadFile(name: String, mimeType: String, data: Data, parentFolderID: String) async throws -> DriveFile {
        file("new", name, mimeType)
    }
}

private let folder = DriveFile.folderMime

final class GoogleTests: XCTestCase {
    func testGmailFailureKeepsStatusReasonTextAndExtra() {
        let body = Data(#"{"error":{"code":403,"message":"User-rate limit exceeded.","errors":[{"domain":"usageLimits","reason":"userRateLimitExceeded"}],"status":"PERMISSION_DENIED"}}"#.utf8)
        let result = FailureEngine.classify(GoogleFailure.api(.gmail, APIFault(status: 403, data: body)))
        XCTAssertEqual(result.kind, .transient)
        XCTAssertEqual(result.original.provider, "gmail")
        XCTAssertEqual(result.original.status, 403)
        XCTAssertEqual(result.original.code, "userRateLimitExceeded")
        XCTAssertEqual(result.original.text, "User-rate limit exceeded.")
        XCTAssertEqual(result.original.extra["domain"], "usageLimits")
        XCTAssertEqual(result.original.extra["state"], "PERMISSION_DENIED")
        XCTAssertEqual(Hint(text: "t", classification: result).codeKey, "hint.code.gmail.403.userRateLimitExceeded")
    }

    func testGmailFailureTable() {
        let table: [(Int, String?, FailureKind)] = [
            (403, "rateLimitExceeded", .transient), (403, "dailyLimitExceeded", .rejected), (429, nil, .transient),
            (500, "backendError", .transient), (503, nil, .transient), (401, "authError", .signIn),
            (404, "notFound", .rejected),
        ]
        for (status, reason, kind) in table {
            XCTAssertEqual(FailureEngine.classify(GoogleFailure.api(.gmail, APIFault(status: status, reason: reason))).kind, kind)
        }
    }

    func testOAuthFailureKeepsErrorAndDescription() {
        let body = Data(#"{"error":"invalid_grant","error_description":"Token has been expired or revoked."}"#.utf8)
        let result = FailureEngine.classify(GoogleFailure.api(.oauth, APIFault(status: 400, data: body)))
        XCTAssertEqual(result.kind, .signIn)
        XCTAssertEqual(result.original.label, "oauth.400.invalid_grant")
        XCTAssertEqual(result.original.text, "Token has been expired or revoked.")
        XCTAssertEqual(FailureEngine.classify(GoogleFailure.api(.oauth, APIFault(status: 400, reason: "invalid_request"))).kind, .rejected)
        XCTAssertEqual(FailureEngine.classify(GoogleFailure.api(.oauth, APIFault(status: 503))).kind, .transient)
    }

    func testDriveForbiddenAndNotConnectedAndRefreshClassification() {
        XCTAssertEqual(FailureEngine.classify(GoogleFailure.api(.drive, APIFault(status: 403))).kind, .signIn)
        XCTAssertEqual(FailureEngine.classify(GoogleFailure.api(.drive, APIFault(status: 500))).kind, .transient)
        let offline = FailureEngine.classify(GoogleFailure.notConnected(.calendar))
        XCTAssertEqual(offline.kind, .transient)
        XCTAssertEqual(offline.original.label, "calendar.notConnected")
        XCTAssertEqual(FailureEngine.classify(SignInFailure.refreshUnavailable).kind, .signIn)
        XCTAssertEqual(FailureEngine.classify(GoogleFailure.uploadDestinationForbidden("x")).kind, .rejected)
        XCTAssertEqual(FailureEngine.classify(URLError(.timedOut)).kind, .transient)
    }

    func testPortFailureMappingKeepsNotConnectedAndCancellation() {
        XCTAssertEqual(FailureEngine.port(GoogleFailure.notConnected(.gmail)) as? PortFailure, .notConnected)
        XCTAssertTrue(FailureEngine.port(CancellationError()) is CancellationError)
        XCTAssertNotNil((FailureEngine.port(GoogleFailure.decodingFailed) as? PortFailure).map(\.detail))
    }

    func testFaultParsesBothErrorShapes() {
        let google = APIFault(status: 403, data: Data(#"{"error":{"message":"m","errors":[{"reason":"rateLimitExceeded","domain":"d"}],"status":"S"}}"#.utf8))
        XCTAssertTrue(google.isRateLimit)
        XCTAssertEqual(google.domain, "d")
        let oauth = APIFault(status: 400, data: Data(#"{"error":"invalid_grant","error_description":"x","error_uri":"u"}"#.utf8))
        XCTAssertEqual(oauth.reason, "invalid_grant")
        XCTAssertEqual(oauth.errorURI, "u")
        XCTAssertEqual(APIFault(status: 500, data: Data("nope".utf8)).isServerFault, true)
        XCTAssertEqual(RequestPolicy(firstDelay: .seconds(1)).delay(afterAttempt: 3), .seconds(4))
    }

    func testTokenStateRoundTripsAndRejectsIncompleteGrants() throws {
        let state = try TokenState(grant: grant())
        XCTAssertEqual(state.refreshToken, "refresh")
        XCTAssertEqual(try TokenState(grant: state.grant), state)
        XCTAssertThrowsError(try TokenState(grant: Grant(values: [:]))) {
            XCTAssertEqual($0 as? SignInFailure, .grantIncomplete(TokenState.accessKey))
        }
        XCTAssertThrowsError(try TokenState(grant: Grant(values: [TokenState.accessKey: "a"]))) {
            XCTAssertEqual($0 as? SignInFailure, .grantIncomplete(TokenState.expiryKey))
        }
        let renewed = TokenState(token: OAuthToken(accessToken: "n", expiresIn: nil, refreshToken: nil), previousRefresh: "keep",
                                 now: grantStart)
        XCTAssertEqual(renewed.refreshToken, "keep")
        XCTAssertEqual(renewed.expiresAt, grantStart.addingTimeInterval(3600))
    }

    func testAccessTokenClientUsesTheLiveTokenWithoutRefreshing() async throws {
        let refresher = StubRefresher(result: .failure(.decodingFailed))
        let client = AccessTokenClient(state: try TokenState(grant: grant()), refresher: refresher, clock: { grantStart })
        let token = try await client.validAccessToken()
        XCTAssertEqual(token, "access")
        XCTAssertEqual(refresher.count.with { $0 }, 0)
    }

    func testAccessTokenClientRefreshesAfterExpiryAndReportsTheRenewal() async throws {
        let renewed = Locked<[Grant]>([])
        let failed = Locked<Int>(0)
        let refresher = StubRefresher(result: .success(OAuthToken(accessToken: "fresh", expiresIn: 3600, refreshToken: nil)))
        let client = AccessTokenClient(
            state: try TokenState(grant: grant(expiresIn: 30)), refresher: refresher, clock: { grantStart },
            renewal: GrantRenewal(renewed: { grant in renewed.with { $0.append(grant) } }, failed: { _ in failed.with { $0 += 1 } }))
        let first = try await client.validAccessToken()
        let second = try await client.validAccessToken()
        XCTAssertEqual([first, second], ["fresh", "fresh"])
        XCTAssertEqual(refresher.count.with { $0 }, 1)
        XCTAssertEqual(renewed.with { $0 }.first?.values[TokenState.refreshKey], "refresh")
        XCTAssertEqual(failed.with { $0 }, 0)
    }

    func testAccessTokenClientReportsRejectionsButNotOutages() async throws {
        let failed = Locked<Int>(0)
        let renewal = GrantRenewal(renewed: { _ in }, failed: { _ in failed.with { $0 += 1 } })
        func run(_ result: Result<OAuthToken, GoogleFailure>, refresh: String? = "refresh") async {
            let client = AccessTokenClient(state: (try? TokenState(grant: grant(expiresIn: 0, refresh: refresh)))!,
                                           refresher: StubRefresher(result: result), clock: { grantStart }, renewal: renewal)
            _ = try? await client.validAccessToken()
        }
        await run(.failure(.api(.oauth, APIFault(status: 400, reason: "invalid_grant"))))
        XCTAssertEqual(failed.with { $0 }, 1)
        await run(.failure(.api(.oauth, APIFault(status: 503))))
        XCTAssertEqual(failed.with { $0 }, 1)
        await run(.failure(.decodingFailed), refresh: nil)
        XCTAssertEqual(failed.with { $0 }, 2)
    }

    func testRequestClientMapsTokenFailureStatusAndBadResponses() async throws {
        let http = FakeHttp { _ in (403, #"{"error":{"message":"No","errors":[{"reason":"insufficientPermissions"}]}}"#) }
        let requests = RequestClient(http: http, tokens: StubTokens(), product: .calendar)
        let url = try RequestClient.url("https://x.test/a", query: [URLQueryItem(name: "k", value: "v w")])
        do {
            try await requests.send(url)
            XCTFail("must throw")
        } catch GoogleFailure.api(.calendar, let fault) {
            XCTAssertEqual(fault.status, 403)
            XCTAssertEqual(fault.reason, "insufficientPermissions")
        }
        XCTAssertEqual(http.calls.first?.authorization, "Bearer token")
        XCTAssertEqual(http.calls.first?.query, "k=v%20w")
        do {
            try await RequestClient(http: http, tokens: RefusingTokens(), product: .contacts).send(url)
            XCTFail("must throw")
        } catch {
            XCTAssertEqual(error as? GoogleFailure, .notConnected(.contacts))
        }
        XCTAssertEqual(http.calls.count, 1)
    }

    func testOAuthClientBuildsTheAuthorizationRequestAndReadsTheRedirect() throws {
        let oauth = OAuthClient(config: ClientConfig(clientID: "cid", clientSecret: ""), http: FakeHttp())
        let params = try oauth.authorization(scopes: [.gmailReadonly, .drive], redirectURI: "http://127.0.0.1:5")
        let items = Dictionary(uniqueKeysWithValues: URLComponents(url: params.url, resolvingAgainstBaseURL: false)!
            .queryItems!.map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(items["client_id"], "cid")
        XCTAssertEqual(items["code_challenge_method"], "S256")
        XCTAssertEqual(items["access_type"], "offline")
        XCTAssertEqual(items["scope"], "https://www.googleapis.com/auth/gmail.readonly https://www.googleapis.com/auth/drive")
        XCTAssertEqual(items["state"], params.state)
        XCTAssertEqual(items["code_challenge"], params.pkce.challenge)
        let good = try XCTUnwrap(URL(string: "http://127.0.0.1:5/?code=abc&state=\(params.state)"))
        XCTAssertEqual(oauth.code(from: good, expectedState: params.state), "abc")
        XCTAssertNil(oauth.code(from: good, expectedState: "other"))
        XCTAssertNil(oauth.code(from: try XCTUnwrap(URL(string: "http://127.0.0.1:5/?state=\(params.state)")), expectedState: params.state))
    }

    func testPkceChallengeIsTheSha256OfTheVerifier() {
        let pkce = PkceChallenge.generate()
        XCTAssertGreaterThanOrEqual(pkce.verifier.count, 43)
        XCTAssertFalse(pkce.verifier.contains("="))
        XCTAssertNotEqual(PkceChallenge.generate().verifier, pkce.verifier)
    }

    func testTokenRequestsCarryTheSecretOnlyWhenConfigured() async throws {
        let http = FakeHttp { _ in (200, #"{"access_token":"a","expires_in":10,"refresh_token":"r"}"#) }
        let withSecret = OAuthClient(config: ClientConfig(clientID: "cid", clientSecret: "sec"), http: http)
        let token = try await withSecret.exchange(code: "c", verifier: "v", redirectURI: "http://127.0.0.1:5")
        XCTAssertEqual(token, OAuthToken(accessToken: "a", expiresIn: 10, refreshToken: "r"))
        _ = try await OAuthClient(config: ClientConfig(clientID: "cid", clientSecret: ""), http: http).refresh(refreshToken: "r1")
        let first = String(decoding: http.calls[0].body, as: UTF8.self)
        let second = String(decoding: http.calls[1].body, as: UTF8.self)
        XCTAssertTrue(first.contains("client_secret=sec") && first.contains("grant_type=authorization_code"))
        XCTAssertTrue(first.contains("redirect_uri=http%3A%2F%2F127.0.0.1%3A5"))
        XCTAssertTrue(second.contains("refresh_token=r1") && !second.contains("client_secret"))
        XCTAssertEqual(http.calls[0].path, "/token")
    }

    func testTokenRequestFailuresKeepTheOAuthFault() async {
        let http = FakeHttp { _ in (400, #"{"error":"invalid_grant","error_description":"gone"}"#) }
        do {
            _ = try await OAuthClient(config: ClientConfig(clientID: "c", clientSecret: ""), http: http).refresh(refreshToken: "r")
            XCTFail("must throw")
        } catch GoogleFailure.api(.oauth, let fault) {
            XCTAssertEqual(fault.reason, "invalid_grant")
        } catch {
            XCTFail("\(error)")
        }
        let garbled = FakeHttp { _ in (200, "not json") }
        do {
            _ = try await OAuthClient(config: ClientConfig(clientID: "c", clientSecret: ""), http: garbled).refresh(refreshToken: "r")
            XCTFail("must throw")
        } catch {
            XCTAssertEqual(error as? GoogleFailure, .decodingFailed)
        }
    }

    func testSignInRunsTheWholeFlowThroughTheRedirectPort() async throws {
        let http = FakeHttp { _ in (200, #"{"access_token":"a","expires_in":3600,"refresh_token":"r"}"#) }
        let opened = Locked<URL?>(nil)
        let signIn = SignInClient(
            oauth: OAuthClient(config: ClientConfig(clientID: "id", clientSecret: ""), http: http),
            openBrowser: { url in
                opened.with { $0 = url }
                return true
            },
            makeRedirect: {
                FakeRedirect { _ in
                    let state = URLComponents(url: opened.with { $0 }!, resolvingAgainstBaseURL: false)!
                        .queryItems!.first { $0.name == "state" }!.value!
                    return URL(string: "http://127.0.0.1:9/?code=the-code&state=\(state)")!
                }
            },
            clock: { grantStart })
        let result = try await signIn.signIn(inlet([.mail]), input: [:])
        XCTAssertEqual(result.values[TokenState.accessKey], "a")
        XCTAssertEqual(result.values[TokenState.refreshKey], "r")
        XCTAssertEqual(result.values[TokenState.expiryKey], String(grantStart.addingTimeInterval(3600).timeIntervalSince1970))
        XCTAssertTrue(String(decoding: http.calls[0].body, as: UTF8.self).contains("code=the-code"))
    }

    func testSignInFailsWhenTheBrowserDoesNotOpenOrTheStateDiffers() async {
        let oauth = OAuthClient(config: ClientConfig(clientID: "id", clientSecret: ""), http: FakeHttp())
        let redirect = FakeRedirect { _ in URL(string: "http://127.0.0.1:9/?code=c&state=wrong")! }
        let closed = SignInClient(oauth: oauth, openBrowser: { _ in false }, makeRedirect: { redirect }, clock: { grantStart })
        do {
            _ = try await closed.signIn(inlet([.mail]), input: [:])
            XCTFail("must throw")
        } catch {
            XCTAssertEqual(error as? SignInFailure, .browserFailed)
        }
        XCTAssertEqual(redirect.stopped.with { $0 }, 1)
        let mismatch = SignInClient(oauth: oauth, openBrowser: { _ in true }, makeRedirect: { redirect }, clock: { grantStart })
        do {
            _ = try await mismatch.signIn(inlet([.mail]), input: [:])
            XCTFail("must throw")
        } catch {
            XCTAssertEqual(error as? SignInFailure, .redirectStateMismatch)
        }
    }

    func testSignInRenewsFromTheRefreshTokenAndRefusesWithoutOne() async throws {
        let http = FakeHttp { _ in (200, #"{"access_token":"fresh","expires_in":100}"#) }
        let signIn = SignInClient(oauth: OAuthClient(config: ClientConfig(clientID: "id", clientSecret: ""), http: http),
                                  openBrowser: { _ in true }, makeRedirect: { FakeRedirect { $0 } }, clock: { grantStart })
        let renewed = try await signIn.renew(grant())
        XCTAssertEqual(renewed.values[TokenState.accessKey], "fresh")
        XCTAssertEqual(renewed.values[TokenState.refreshKey], "refresh")
        do {
            _ = try await signIn.renew(grant(refresh: nil))
            XCTFail("must throw")
        } catch {
            XCTAssertEqual(error as? SignInFailure, .refreshUnavailable)
        }
        try await signIn.signOut(inlet([.mail]))
    }

    func testProbeNamesTheFirstFailingStep() async throws {
        func probe(_ handler: @escaping FakeHttp.Responder, _ grant: Grant = grant()) async throws -> ProbeResult {
            try await router(FakeHttp(handler)).probe.probe(inlet([.mail]), grant)
        }
        let green = try await probe { call in
            call.path.hasSuffix("/userinfo") ? (200, #"{"email":"a@example.test","name":"A"}"#)
                : (200, #"{"labels":[{"id":"Label_1","name":"Kunden","type":"user"}]}"#)
        }
        XCTAssertEqual(green, ProbeResult(account: "a@example.test"))
        let userinfo = try await probe { _ in (401, "") }
        XCTAssertEqual(userinfo.rejection?.text, "hint.google.userinfo")
        XCTAssertEqual(userinfo.rejection?.detail, "HTTP 401")
        XCTAssertEqual(userinfo.account, "g")
        let labels = try await probe { call in call.path.hasSuffix("/userinfo") ? (200, #"{"email":"a@example.test"}"#) : (403, "") }
        XCTAssertEqual(labels.rejection?.text, "hint.google.labels")
        XCTAssertEqual(labels.rejection?.detail, "HTTP 403")
        XCTAssertEqual(labels.account, "a@example.test")
        let broken = try await probe({ _ in (200, "{}") }, Grant(values: [:]))
        XCTAssertEqual(broken.rejection?.text, "hint.google.grant")
        let expired = try await probe({ _ in (400, #"{"error":"invalid_grant"}"#) }, grant(expiresIn: 0))
        XCTAssertEqual(expired.rejection?.text, "hint.google.token")
        XCTAssertEqual(expired.rejection?.kind, .signIn)
        XCTAssertEqual(expired.rejection?.code, "oauth.400.invalid_grant")
    }

    func testClientConfigLoadsFromFileAndRejectsMissingAndInvalid() throws {
        let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["TMPDIR"] ?? NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ClientConfigStore(directory: directory)
        let path = directory.appendingPathComponent(ClientConfigStore.fileName)
        XCTAssertThrowsError(try store.load()) { XCTAssertEqual($0 as? SignInFailure, .clientConfigMissing(path.path)) }
        try Data("nope".utf8).write(to: path)
        XCTAssertThrowsError(try store.load()) { XCTAssertEqual($0 as? SignInFailure, .clientConfigInvalid(path.path)) }
        try Data(#"{"clientID":" ","clientSecret":"s"}"#.utf8).write(to: path)
        XCTAssertThrowsError(try store.load()) { XCTAssertEqual($0 as? SignInFailure, .clientConfigInvalid(path.path)) }
        try Data(#"{"clientID":"cid","clientSecret":"sec"}"#.utf8).write(to: path)
        XCTAssertEqual(try store.load(), ClientConfig(clientID: "cid", clientSecret: "sec"))
        try Data(#"{"clientID":"cid"}"#.utf8).write(to: path)
        XCTAssertEqual(try store.load().clientSecret, "")
    }

    func testUserInfoFallsBackToTheEmailForBlankNames() async throws {
        let http = FakeHttp { _ in (200, #"{"email":"a@x.test","name":"  "}"#) }
        let info = try await UserInfoClient(http: http).fetchUserInfo(accessToken: "t")
        XCTAssertEqual(info, UserInfo(email: "a@x.test", displayName: "a@x.test"))
        XCTAssertEqual(http.calls.first?.authorization, "Bearer t")
        XCTAssertThrowsError(try UserInfoClient.parse(Data("{}".utf8))) { XCTAssertEqual($0 as? GoogleFailure, .decodingFailed) }
    }

    func testMailTransportFoldersListSystemFoldersThenUserLabels() async throws {
        let http = FakeHttp { _ in
            (200, #"{"labels":[{"id":"INBOX","name":"INBOX","type":"system"},{"id":"Label_1","name":"Kunden","type":"user"},{"id":"Label_2","name":"Archiv","type":"user"}]}"#)
        }
        let folders = try await mailClient(http).listFolders()
        XCTAssertEqual(folders.prefix(7).map(\.role), [.inbox, .starred, .sent, .drafts, .all, .spam, .trash])
        XCTAssertEqual(folders.filter { $0.role == .other }.map(\.id), ["Label_2", "Label_1"])
        XCTAssertEqual(folders.filter { $0.role == .other }.map(\.name), ["Archiv", "Kunden"])
    }

    func testMailTransportActionsUseTheMatchingEndpoints() async throws {
        let http = FakeHttp()
        let mail = mailClient(http)
        let messages = "/gmail/v1/users/me/messages"
        try await mail.archive(messageID: "m1")
        try await mail.trash(messageID: "m1")
        try await mail.markSpam(messageID: "m1")
        try await mail.move(messageID: "m1", toFolderID: "Label_7")
        try await mail.move(messageID: "m1", toFolderID: "TRASH")
        try await mail.move(messageID: "m1", toFolderID: "ALL")
        try await mail.move(messageID: "m1", toFolderID: "INBOX")
        let calls = http.calls
        XCTAssertEqual(calls.map { $0.method + " " + $0.path }, [
            "POST \(messages)/m1/modify", "POST \(messages)/m1/trash", "POST \(messages)/m1/modify",
            "POST \(messages)/m1/modify", "POST \(messages)/m1/trash", "POST \(messages)/m1/modify",
            "POST \(messages)/m1/modify",
        ])
        XCTAssertEqual(try json(calls[0]) as? [String: [String]], ["removeLabelIds": ["INBOX"]])
        XCTAssertEqual(calls[1].body, Data())
        XCTAssertEqual(try json(calls[2]) as? [String: [String]], ["addLabelIds": ["SPAM"], "removeLabelIds": ["INBOX"]])
        XCTAssertEqual(try json(calls[3]) as? [String: [String]], ["addLabelIds": ["Label_7"], "removeLabelIds": ["INBOX"]])
        XCTAssertEqual(try json(calls[6]) as? [String: [String]], ["addLabelIds": ["INBOX"]])
    }

    func testMovingIntoAFolderThatCannotHoldMailIsRefusedWithoutARequest() async {
        let http = FakeHttp()
        for target in ["SENT", "STARRED", "DRAFT"] {
            do {
                try await mailClient(http).move(messageID: "m1", toFolderID: target)
                XCTFail("must throw")
            } catch {
                XCTAssertEqual(error as? MailFailure, .folderNotFound(target))
            }
        }
        XCTAssertTrue(http.calls.isEmpty)
    }

    func testFlagsMapToLabels() async throws {
        let http = FakeHttp()
        let mail = mailClient(http)
        try await mail.setFlags(messageID: "m", add: [.seen, .flagged], remove: [])
        try await mail.setFlags(messageID: "m", add: [], remove: [.seen, .flagged])
        try await mail.setFlags(messageID: "m", add: [.answered], remove: [.draft])
        try await mail.setFlags(messageID: "m", add: [.deleted], remove: [])
        XCTAssertEqual(http.calls.count, 3)
        let first = try json(http.calls[0]) as? [String: [String]]
        XCTAssertEqual(Set(first?["addLabelIds"] ?? []), ["STARRED"])
        XCTAssertEqual(Set(first?["removeLabelIds"] ?? []), ["UNREAD"])
        let second = try json(http.calls[1]) as? [String: [String]]
        XCTAssertEqual(Set(second?["addLabelIds"] ?? []), ["UNREAD"])
        XCTAssertEqual(Set(second?["removeLabelIds"] ?? []), ["STARRED"])
        XCTAssertEqual(http.calls[2].path, "/gmail/v1/users/me/messages/m/trash")
    }

    func testAttachmentIsDownloadedFromTheAttachmentEndpointAndDecoded() async throws {
        let http = FakeHttp { _ in (200, #"{"data":"SGVsbG8h"}"#) }
        let data = try await mailClient(http).fetchAttachment(messageID: "m1", attachmentID: "a1")
        XCTAssertEqual(data, Data("Hello!".utf8))
        XCTAssertEqual(http.calls.first?.path, "/gmail/v1/users/me/messages/m1/attachments/a1")
        let broken = FakeHttp { _ in (200, "{}") }
        do {
            _ = try await mailClient(broken).fetchAttachment(messageID: "m", attachmentID: "a")
            XCTFail("must throw")
        } catch {
            XCTAssertEqual(error as? GoogleFailure, .decodingFailed)
        }
    }

    func testBodyCarriesTextHtmlInlineImagesAndAttachments() async throws {
        let parts = #"""
        [{"mimeType":"text/plain","body":{"data":"aGk="}},
         {"mimeType":"text/html","body":{"data":"PGI-aGk8L2I-"}},
         {"mimeType":"image/png","headers":[{"name":"Content-ID","value":"<logo>"}],"body":{"attachmentId":"img1","size":3}},
         {"mimeType":"application/pdf","filename":"a.pdf","body":{"attachmentId":"att1","size":42}}]
        """#
        let http = FakeHttp { _ in (200, "{\"id\":\"m1\",\"payload\":{\"mimeType\":\"multipart/mixed\",\"parts\":\(parts)}}") }
        let body = try await mailClient(http).fetchBody(messageID: "m1")
        XCTAssertEqual(body.text, "hi")
        XCTAssertEqual(body.html, "<b>hi</b>")
        XCTAssertEqual(body.inlineImages, ["logo": "img1"])
        XCTAssertEqual(body.attachments, [AttachmentInfo(id: "att1", filename: "a.pdf", mimeType: "application/pdf", sizeBytes: 42)])
        XCTAssertEqual(http.calls.first?.query, "format=full")
    }

    func testPlainBodyFallsBackToHtmlThenSnippet() async throws {
        let html = FakeHttp { _ in (200, #"{"id":"m","payload":{"mimeType":"text/html","body":{"data":"PHA-aGk8L3A-"}}}"#) }
        let fromHtml = try await gmail(html).fetchBody(messageID: "m")
        XCTAssertEqual(fromHtml, "hi")
        let snippet = FakeHttp { _ in (200, #"{"id":"m","snippet":"only snippet"}"#) }
        let fromSnippet = try await gmail(snippet).fetchBody(messageID: "m")
        XCTAssertEqual(fromSnippet, "only snippet")
        let garbled = try await gmail(FakeHttp { _ in (200, "x") }).fetchBody(messageID: "m")
        XCTAssertEqual(garbled, "")
    }

    func testThreadReturnsEveryMessageAsSummaries() async throws {
        let first = #"{"id":"m1","threadId":"t1","snippet":"one","labelIds":["INBOX"],"payload":{"headers":[{"name":"Subject","value":"Plan"}]}}"#
        let second = #"{"id":"m2","threadId":"t1","snippet":"two","labelIds":["INBOX","UNREAD"],"payload":{"headers":[{"name":"Subject","value":"Re: Plan"}]}}"#
        let http = FakeHttp { _ in (200, "{\"messages\":[\(first),\(second)]}") }
        let thread = try await mailClient(http).fetchThread(messageID: "m2", threadID: "t1")
        XCTAssertEqual(thread.map(\.id), ["m1", "m2"])
        XCTAssertEqual(thread.map(\.subject), ["Plan", "Re: Plan"])
        XCTAssertEqual(thread[0].flags, [.seen])
        XCTAssertEqual(thread[1].flags, [])
        XCTAssertEqual(http.calls.first?.path, "/gmail/v1/users/me/threads/t1")
        XCTAssertTrue(try XCTUnwrap(http.calls.first?.query).contains("maxResults=20"))
    }

    func testListMessagesScopesTheLabelAndKeepsOrderAcrossDetails() async throws {
        let http = FakeHttp { call in
            if call.path.hasSuffix("/labels") { return (200, #"{"labels":[{"id":"Label_1","name":"Kun \"den\"","type":"user"}]}"#) }
            if call.path.hasSuffix("/messages") { return (200, #"{"messages":[{"id":"a"},{"id":"b"},{"id":"c"}],"nextPageToken":"n"}"#) }
            let id = String(call.path.split(separator: "/").last ?? "")
            return (200, #"{"id":"\#(id)","threadId":"t","internalDate":"1000000","labelIds":["UNREAD","STARRED","DRAFT"],"payload":{"headers":[{"name":"From","value":"\"Ann B\" <ann@x.test>"},{"name":"Subject","value":"S\#(id)"},{"name":"Message-ID","value":"<id@x>"}]}}"#)
        }
        let mail = mailClient(http)
        let page = try await mail.listMessages(folderID: "Label_1", query: "plan", pageToken: "p", maxResults: 5)
        XCTAssertEqual(page.messages.map(\.id), ["a", "b", "c"])
        XCTAssertEqual(page.nextPageToken, "n")
        let listCall = try XCTUnwrap(http.calls.first { $0.path.hasSuffix("/messages") })
        XCTAssertTrue(listCall.query.contains("q=label:%22Kun%20%5C%22den%5C%22%22%20plan"))
        XCTAssertTrue(listCall.query.contains("pageToken=p"))
        let first = page.messages[0]
        XCTAssertEqual(first.from, "Ann B")
        XCTAssertEqual(first.flags, [.flagged, .draft])
        XCTAssertEqual(first.messageIDHeader, "<id@x>")
        XCTAssertEqual(first.receivedAt, Date(timeIntervalSince1970: 1000))
        let all = try await mail.listMessages(folderID: "ALL", query: nil, pageToken: nil, maxResults: 1)
        XCTAssertEqual(all.messages.count, 3)
        XCTAssertTrue(try XCTUnwrap(http.calls.last { $0.path.hasSuffix("/messages") }).query.hasPrefix("q=&"))
        do {
            _ = try await mail.listMessages(folderID: "Missing", query: nil, pageToken: nil, maxResults: 1)
            XCTFail("must throw")
        } catch {
            XCTAssertEqual(error as? MailFailure, .folderNotFound("Missing"))
        }
    }

    func testDetailFetchRetriesRateLimitsUpToThePolicyAndThenFails() async throws {
        let attempts = Locked<Int>(0)
        let http = FakeHttp { call in
            if call.path.hasSuffix("/messages") { return (200, #"{"messages":[{"id":"a"}]}"#) }
            let attempt = attempts.with { count -> Int in
                count += 1
                return count
            }
            return attempt < 3 ? (503, "") : (200, #"{"id":"a"}"#)
        }
        let page = try await gmail(http).listMessages(query: "q", maxResults: 1, pageToken: nil)
        XCTAssertEqual(page.messages.map(\.id), ["a"])
        XCTAssertEqual(attempts.with { $0 }, 3)
        attempts.with { $0 = 0 }
        let failing = FakeHttp { call in
            call.path.hasSuffix("/messages") ? (200, #"{"messages":[{"id":"a"}]}"#) : (404, "")
        }
        do {
            _ = try await gmail(failing).listMessages(query: "q", maxResults: 1, pageToken: nil)
            XCTFail("must throw")
        } catch GoogleFailure.api(.gmail, let fault) {
            XCTAssertEqual(fault.status, 404)
        }
        XCTAssertEqual(failing.calls.count, 2)
    }

    func testEmptyListSkipsDetailRequests() async throws {
        let http = FakeHttp { _ in (200, #"{"resultSizeEstimate":0}"#) }
        let page = try await gmail(http).listMessages(query: "q", maxResults: 3, pageToken: nil)
        XCTAssertEqual(page, GmailPage(messages: [], nextPageToken: nil))
        XCTAssertEqual(http.calls.count, 1)
    }

    func testDraftsAreCreatedUpdatedDeletedAndSent() async throws {
        let http = FakeHttp { _ in (200, #"{"id":"d9"}"#) }
        let mail = mailClient(http)
        let draft = Draft(to: "ann@x.test", subject: "Hi", body: "text", threadID: "t1", messageID: "abc")
        let created = try await mail.saveDraft(draft, replacing: nil)
        let updated = try await mail.saveDraft(draft, replacing: "d1")
        try await mail.deleteDraft(id: "d1")
        try await mail.sendDraft(id: "d1")
        try await mail.send(draft)
        XCTAssertEqual([created, updated], ["d9", "d9"])
        let drafts = "/gmail/v1/users/me/drafts"
        XCTAssertEqual(http.calls.map { $0.method + " " + $0.path }, [
            "POST \(drafts)", "PUT \(drafts)/d1", "DELETE \(drafts)/d1", "POST \(drafts)/send",
            "POST /gmail/v1/users/me/messages/send",
        ])
        XCTAssertEqual(try json(http.calls[3]) as? [String: String], ["id": "d1"])
        let message = try XCTUnwrap(json(http.calls[0])["message"] as? [String: String])
        XCTAssertEqual(message["threadId"], "t1")
        let raw = String(decoding: try XCTUnwrap(Base64Engine.decodeURL(try XCTUnwrap(message["raw"]))), as: UTF8.self)
        XCTAssertTrue(raw.contains("To: ann@x.test"))
        XCTAssertTrue(raw.contains("Subject: Hi"))
        XCTAssertTrue(raw.contains("Message-ID: <abc@mail.gmail.com>"))
        let direct = try json(http.calls[4])
        XCTAssertEqual(direct["threadId"] as? String, "t1")
        XCTAssertNotNil(direct["raw"])
    }

    func testSentMessagesWithoutAThreadOmitTheThreadId() {
        let payload = DraftMimeEngine.payload(Draft(to: "a@x.test", subject: "S", body: "b", inReplyTo: "ref@x"))
        XCTAssertNil(payload["threadId"])
        let raw = String(decoding: Base64Engine.decodeURL(payload["raw"] ?? "") ?? Data(), as: UTF8.self)
        XCTAssertTrue(raw.contains("In-Reply-To: <ref@x>"))
    }

    func testAttachmentsGoThroughTheMailBuilder() throws {
        let draft = Draft(to: "a@x.test", subject: "S", body: "b", attachments: [Attachment(filename: "a.txt", mimeType: "text/plain", data: Data("hi".utf8))])
        let raw = String(decoding: Base64Engine.decodeURL(DraftMimeEngine.payload(draft)["raw"] ?? "") ?? Data(), as: UTF8.self)
        XCTAssertTrue(raw.contains("multipart/mixed"))
        XCTAssertTrue(raw.contains("filename=\"a.txt\""))
    }

    func testAStoredDraftIsOpenedThroughTheDraftIDMap() async throws {
        let list = #"{"drafts":[{"id":"d1","message":{"id":"m5"}}]}"#
        let draft = #"{"id":"d1","message":{"id":"m5","threadId":"t5","payload":{"headers":[{"name":"To","value":"ann@x.test"},{"name":"Subject","value":"Plan"},{"name":"In-Reply-To","value":"<r@x>"}],"mimeType":"multipart/mixed","parts":[{"mimeType":"text/plain","body":{"data":"aGk="}},{"mimeType":"application/pdf","filename":"a.pdf","body":{"attachmentId":"att","size":2}}]}}}"#
        let http = FakeHttp { call in
            if call.path.hasSuffix("/attachments/att") { return (200, #"{"data":"SGVsbG8h"}"#) }
            return call.path.hasSuffix("/d1") ? (200, draft) : (200, list)
        }
        let stored = try await mailClient(http).fetchDraft(messageID: "m5")
        XCTAssertEqual(stored.id, "d1")
        XCTAssertEqual(stored.draft.to, "ann@x.test")
        XCTAssertEqual(stored.draft.subject, "Plan")
        XCTAssertEqual(stored.draft.threadID, "t5")
        XCTAssertEqual(stored.draft.body, "hi")
        XCTAssertEqual(stored.draft.inReplyTo, "<r@x>")
        XCTAssertEqual(stored.draft.attachments, [Attachment(filename: "a.pdf", mimeType: "application/pdf", data: Data("Hello!".utf8))])
    }

    func testAMessageThatIsNoDraftIsNotFoundAsOne() async {
        let http = FakeHttp { _ in (200, #"{"drafts":[]}"#) }
        do {
            _ = try await mailClient(http).fetchDraft(messageID: "m5")
            XCTFail("must throw")
        } catch {
            XCTAssertEqual(error as? MailFailure, .messageNotFound("m5"))
        }
        let missing = FakeHttp { call in call.path.hasSuffix("/d1") ? (200, "{}") : (200, #"{"drafts":[{"id":"d1","message":{"id":"m5"}}]}"#) }
        do {
            _ = try await mailClient(missing).fetchDraft(messageID: "m5")
            XCTFail("must throw")
        } catch {
            XCTAssertEqual(error as? GoogleFailure, .decodingFailed)
        }
    }

    func testAProviderRefusalSurfacesAsTheOriginalGoogleFault() async {
        let http = FakeHttp { _ in (403, #"{"error":{"code":403,"message":"Insufficient Permission","errors":[{"domain":"global","reason":"insufficientPermissions"}]}}"#) }
        do {
            try await mailClient(http).archive(messageID: "m1")
            XCTFail("must throw")
        } catch GoogleFailure.api(.gmail, let fault) {
            XCTAssertEqual(fault.status, 403)
            XCTAssertEqual(fault.reason, "insufficientPermissions")
        } catch {
            XCTFail("\(error)")
        }
    }

    func testWasSentSearchesTheSentFolderByMessageId() async throws {
        let sent = FakeHttp { call in call.path.hasSuffix("/messages") ? (200, #"{"messages":[{"id":"a"}]}"#) : (200, #"{"id":"a"}"#) }
        let found = try await mailClient(sent).wasSent(messageID: "abc")
        XCTAssertTrue(found)
        XCTAssertTrue(try XCTUnwrap(sent.calls.first).query.contains("rfc822msgid:abc@mail.gmail.com"))
        let none = try await mailClient(FakeHttp { _ in (200, "{}") }).wasSent(messageID: "abc")
        XCTAssertFalse(none)
    }

    func testMessageParsingHelpers() {
        XCTAssertEqual(MessageParser.senderName(from: "\"Ann\" <a@x.test>"), "Ann")
        XCTAssertEqual(MessageParser.senderName(from: "<a@x.test>"), "<a@x.test>")
        XCTAssertEqual(MessageParser.senderName(from: "a@x.test"), "a@x.test")
        XCTAssertEqual(MessageParser.decodeEntities("It&#39;s &amp; &lt;b&gt; &#x41; &bogus; &"), "It's & <b> A &bogus; &")
        XCTAssertNotNil(MessageParser.emailDate("Mon, 5 Jan 2026 10:00:00 +0100 (CET)"))
        XCTAssertNotNil(MessageParser.emailDate("5 Jan 2026 10:00 +0100"))
        XCTAssertNil(MessageParser.emailDate("soon"))
        XCTAssertEqual(Base64Engine.decodeURL(Base64Engine.encodeURL(Data([251, 255, 254]))), Data([251, 255, 254]))
    }

    func testMessageCacheStoreExpires() async {
        let now = Locked<Date>(grantStart)
        let cache = MessageCacheStore(timeToLive: 10, clock: { now.with { $0 } })
        let message = GmailMessage(id: "a", subject: "s", from: "f")
        await cache.store([message], for: "q")
        var hit = await cache.cached(for: "q")
        XCTAssertEqual(hit, [message])
        now.with { $0 = grantStart.addingTimeInterval(11) }
        hit = await cache.cached(for: "q")
        XCTAssertNil(hit)
    }

    func testMailSearchAnswersFromTheCacheAndMapsHits() async throws {
        let http = FakeHttp { call in
            if call.path.hasSuffix("/messages") { return (200, #"{"messages":[{"id":"a"},{"id":"b"}]}"#) }
            return (200, #"{"id":"x","snippet":"it&#39;s","labelIds":["INBOX"],"payload":{"parts":[{"filename":"f.pdf","mimeType":"application/pdf","body":{"attachmentId":"z","size":1}}],"headers":[{"name":"Subject","value":"S"},{"name":"From","value":"A <a@x.test>"}]}}"#)
        }
        let search = MailSearchClient(gmail: gmail(http), cache: MessageCacheStore(), account: "g")
        let first = try await search.search(query: "q", limit: 2)
        XCTAssertEqual(first.map(\.id), ["x", "x"])
        XCTAssertEqual(first[0].snippet, "it's")
        XCTAssertEqual(first[0].attachmentNames, ["f.pdf"])
        XCTAssertEqual(first[0].from, "A")
        let calls = http.calls.count
        let second = try await search.search(query: "q", limit: 1)
        XCTAssertEqual(second.count, 1)
        XCTAssertEqual(http.calls.count, calls)
        let other = MailSearchClient(gmail: gmail(http), cache: MessageCacheStore(), account: "h")
        _ = try await other.search(query: "q", limit: 2)
        XCTAssertGreaterThan(http.calls.count, calls)
        let body = try await search.body(messageID: "x")
        XCTAssertEqual(body, "it&#39;s")
    }

    func testMailSearchMapsFailuresToThePortFailure() async {
        let offline = MailSearchClient(
            gmail: GmailClient(requests: RequestClient(http: FakeHttp(), tokens: RefusingTokens(), product: .gmail)),
            cache: MessageCacheStore(), account: "g")
        do {
            _ = try await offline.search(query: "q", limit: 1)
            XCTFail("must throw")
        } catch {
            XCTAssertEqual(error as? PortFailure, .notConnected)
        }
        let broken = MailSearchClient(gmail: gmail(FakeHttp { _ in (500, "") }), cache: MessageCacheStore(), account: "g")
        do {
            _ = try await broken.body(messageID: "m")
            XCTFail("must throw")
        } catch let failure as PortFailure {
            XCTAssertFalse(failure.detail.isEmpty)
        } catch {
            XCTFail("\(error)")
        }
    }

    func testCalendarListsCalendarsAndEventsInOneRequestPath() async throws {
        let events = #"{"items":[{"id":"e1","summary":"Meet","location":"Room","start":{"dateTime":"2026-01-05T10:00:00+01:00"},"end":{"dateTime":"2026-01-05T11:00:00.500+01:00"}},{"id":"e2","start":{"date":"2026-01-06"},"end":{"date":"2026-01-07"}}]}"#
        let http = FakeHttp { call in
            call.path.hasSuffix("/calendarList") ? (200, #"{"items":[{"id":"primary","summary":"Own"},{"id":"team@x.test","summary":"Team","summaryOverride":"Mine"}]}"#) : (200, events)
        }
        let calendar = CalendarClient(requests: RequestClient(http: http, tokens: StubTokens(), product: .calendar), clock: { grantStart })
        let calendars = try await calendar.listCalendars()
        XCTAssertEqual(calendars, [EventCalendar(id: "primary", title: "Own"), EventCalendar(id: "team@x.test", title: "Mine")])
        let own = try await calendar.upcomingEvents(calendarID: nil, query: "plan", withinDays: 2)
        XCTAssertEqual(own.map(\.id), ["primary#e1", "primary#e2"])
        XCTAssertEqual(own[0].title, "Meet")
        XCTAssertFalse(own[0].isAllDay)
        XCTAssertTrue(own[1].isAllDay)
        XCTAssertEqual(own[1].title, "")
        XCTAssertEqual(own[0].location, "Room")
        XCTAssertNotNil(own[0].endsAt)
        let eventCall = try XCTUnwrap(http.calls.last)
        XCTAssertEqual(eventCall.path, "/calendar/v3/calendars/primary/events")
        XCTAssertTrue(eventCall.query.contains("q=plan") && eventCall.query.contains("maxResults=20"))
        XCTAssertTrue(eventCall.query.contains("timeMin=1970-01-12T13:46:40Z"))
        XCTAssertTrue(eventCall.query.contains("timeMax=1970-01-14T13:46:40Z"))
        let team = try await calendar.upcomingEvents(calendarID: "team@x.test", query: nil, withinDays: 1)
        XCTAssertEqual(team.first?.calendarID, "team@x.test")
        XCTAssertEqual(http.calls.last?.path, "/calendar/v3/calendars/team@x.test/events")
        XCTAssertFalse(try XCTUnwrap(http.calls.last).query.contains("q="))
        XCTAssertThrowsError(try CalendarParser.events(from: Data("x".utf8), calendarID: "c"))
    }

    func testCalendarPortMapsEntriesAndRefs() async throws {
        let http = FakeHttp { call in
            call.path.hasSuffix("/calendarList") ? (200, #"{"items":[{"id":"c1","summary":"One"}]}"#)
                : (200, #"{"items":[{"id":"e","summary":"T","start":{"dateTime":"2026-01-05T10:00:00Z"}}]}"#)
        }
        let port = CalendarListingClient(calendar: CalendarClient(requests: RequestClient(http: http, tokens: StubTokens(), product: .calendar)))
        XCTAssertTrue(port.hasTeamCalendars)
        let refs = try await port.calendars()
        XCTAssertEqual(refs, [CalendarRef(id: "c1", title: "One")])
        let entries = try await port.events(calendarID: "c1", query: nil, withinDays: 3)
        XCTAssertEqual(entries.first?.id, "c1#e")
        XCTAssertEqual(entries.first?.title, "T")
        XCTAssertEqual(entries.first?.isAllDay, false)
    }

    func testContactSearchWarmsUpRetriesOnEmptyAndNormalizesTheQuery() async throws {
        XCTAssertEqual(ContactsClient.normalize(" a_b\tc\n d "), "a b c d")
        XCTAssertEqual(ContactsClient.normalize(nil), "")
        let results = Locked<Int>(0)
        let http = FakeHttp { call in
            guard call.query.contains("query=ann") else { return (200, "{}") }
            let count = results.with { value -> Int in
                value += 1
                return value
            }
            return count == 1 ? (200, "{}") : (200, #"{"results":[{"person":{"resourceName":"people/1","names":[{"displayName":"Ann"}],"emailAddresses":[{"value":"a@x.test"}],"phoneNumbers":[{"value":"1"}],"organizations":[{"name":"Org"}]}},{}]}"#)
        }
        let client = ContactsClient(requests: RequestClient(http: http, tokens: StubTokens(), product: .contacts), retryDelay: .milliseconds(1))
        let contacts = try await client.searchContacts(query: "ann")
        XCTAssertEqual(contacts.count, 2)
        XCTAssertEqual(contacts[0], Contact(id: "people/1", displayName: "Ann", email: "a@x.test", phone: "1", organization: "Org"))
        XCTAssertEqual(contacts[1].displayName, "")
        XCTAssertEqual(http.calls.count, 3)
        XCTAssertEqual(http.calls[0].query.hasPrefix("query=&"), true)
        let empty = try await client.searchContacts(query: "  ")
        XCTAssertTrue(empty.isEmpty)
        XCTAssertEqual(http.calls.count, 3)
        let port = ContactSearchClient(contacts: client)
        let mapped = try await port.search(query: "ann")
        XCTAssertEqual(mapped.first, GoogleContact(displayName: "Ann", organization: "Org", email: "a@x.test", phone: "1"))
    }

    func testDriveListsAllPagesWithFoldersAndTypeLabels() async throws {
        let pages = Locked<[String]>([])
        let http = FakeHttp { call in
            pages.with { $0.append(call.query) }
            if call.query.contains("pageToken=p2") {
                return (200, #"{"files":[{"id":"3","name":"c.png","mimeType":"image\/png"}]}"#)
            }
            return (200, #"{"files":[{"id":"1","name":"A","mimeType":"application\/vnd.google-apps.folder"},{"id":"2","name":"b.pdf","mimeType":"application\/pdf","modifiedTime":"2026-01-05T10:00:00.000Z","webViewLink":"w"}],"nextPageToken":"p2"}"#)
        }
        let files = try await drive(http).listFolder(folderID: "root")
        XCTAssertEqual(files.map(\.id), ["1", "2", "3"])
        XCTAssertEqual(files.map(\.isFolder), [true, false, false])
        XCTAssertEqual(files.map(\.typeLabel), ["google.drive.type.folder", "google.drive.type.pdf", "google.drive.type.image"])
        XCTAssertNotNil(files[1].modifiedAt)
        XCTAssertEqual(files[1].webViewLink, "w")
        XCTAssertEqual(http.calls.count, 2)
        XCTAssertTrue(http.calls[0].query.contains("supportsAllDrives=true"))
        XCTAssertEqual(file("x", "n", "application/zip").typeLabel, "ZIP")
        XCTAssertEqual(file("x", "n", "").typeLabel, "google.drive.type.file")
        XCTAssertEqual(file("x", "n", "application/vnd.google-apps.spreadsheet").typeLabel, "google.drive.type.sheet")
        XCTAssertEqual(file("x", "n", "application/vnd.google-apps.document").typeLabel, "google.drive.type.document")
        XCTAssertEqual(file("x", "n", "application/vnd.google-apps.presentation").typeLabel, "google.drive.type.presentation")
    }

    func testDriveDownloadExportAndNameUseTheDriveEndpoints() async throws {
        let http = FakeHttp { call in call.query.contains("fields=name") ? (200, #"{"name":"Folder"}"#) : (200, "body") }
        let client = drive(http)
        let name = try await client.fileName(of: "f1")
        let media = try await client.downloadContent(fileID: "f1")
        let exported = try await client.exportFile(fileID: "f1", exportMimeType: "text/csv")
        XCTAssertEqual(name, "Folder")
        XCTAssertEqual(media, Data("body".utf8))
        XCTAssertEqual(exported, Data("body".utf8))
        XCTAssertTrue(http.calls[1].query.contains("alt=media"))
        XCTAssertEqual(http.calls[2].path, "/drive/v3/files/f1/export")
        XCTAssertEqual(http.calls[2].query, "mimeType=text/csv")
    }

    func testUploadPutsTheFileIntoTheFolderAsMultipartRelated() async throws {
        let http = FakeHttp { _ in (200, #"{"id":"n","name":"a.pdf","mimeType":"application/pdf","webViewLink":"link"}"#) }
        let uploaded = try await drive(http).uploadFile(name: "a.pdf", mimeType: "application/pdf", data: Data([7]), parentFolderID: "f1")
        XCTAssertEqual(uploaded.id, "n")
        XCTAssertEqual(uploaded.webViewLink, "link")
        let call = try XCTUnwrap(http.calls.last)
        XCTAssertEqual(call.method, "POST")
        XCTAssertEqual(call.path, "/upload/drive/v3/files")
        let body = String(decoding: call.body, as: UTF8.self)
        XCTAssertTrue(body.contains("\"parents\":[\"f1\"]"))
        XCTAssertTrue(body.contains("Content-Type: application/pdf"))
        XCTAssertFalse(body.lowercased().contains("tags"))
    }

    func testUploadIntoAForbiddenFolderIsRefusedBeforeAnyRequest() async {
        let http = FakeHttp()
        do {
            _ = try await drive(http).uploadFile(name: "a", mimeType: "text/plain", data: Data(), parentFolderID: "locked")
            XCTFail("must throw")
        } catch {
            XCTAssertEqual(error as? GoogleFailure, .uploadDestinationForbidden("locked"))
        }
        XCTAssertTrue(http.calls.isEmpty)
        do {
            _ = try await DriveFilesClient(drive: drive(http), projectsRoot: "root")
                .put(name: "a", mimeType: "text/plain", data: Data(), into: "locked")
            XCTFail("must throw")
        } catch {
            XCTAssertEqual(error as? GoogleFailure, .uploadDestinationForbidden("locked"))
        }
        XCTAssertTrue(http.calls.isEmpty)
    }

    func testNoFolderIsForbiddenWithoutConfiguration() async throws {
        let http = FakeHttp { _ in (200, #"{"id":"n","name":"a","mimeType":"text/plain"}"#) }
        _ = try await drive(http, forbidden: []).uploadFile(name: "a", mimeType: "text/plain", data: Data(), parentFolderID: "locked")
        XCTAssertEqual(http.calls.count, 1)
    }

    func testSubfolderIsFoundOrCreated() async throws {
        let found = FakeHttp { _ in (200, #"{"files":[{"id":"sub","name":"X"}]}"#) }
        let existing = try await drive(found).findOrCreateSubfolder(parentID: "p", name: "O'Neil")
        XCTAssertEqual(existing, "sub")
        XCTAssertEqual(found.calls.count, 1)
        XCTAssertTrue(found.calls[0].query.contains("O%5C'Neil"))
        let created = FakeHttp { call in call.method == "POST" ? (200, #"{"id":"new"}"#) : (200, #"{"files":[]}"#) }
        let made = try await drive(created).findOrCreateSubfolder(parentID: "p", name: "X")
        XCTAssertEqual(made, "new")
        let body = try json(try XCTUnwrap(created.calls.last))
        XCTAssertEqual(body["mimeType"] as? String, DriveFile.folderMime)
        XCTAssertEqual(body["parents"] as? [String], ["p"])
    }

    func testSubfolderIsNotCreatedWhenTheLookupFails() async {
        let broken = FakeHttp { call in call.method == "POST" ? (200, #"{"id":"new"}"#) : (500, "{}") }
        do {
            _ = try await drive(broken).findOrCreateSubfolder(parentID: "p", name: "X")
            XCTFail("lookup failure must surface")
        } catch {
            XCTAssertEqual(broken.calls.count, 1)
            XCTAssertEqual(broken.calls.first?.method, "GET")
        }
    }

    func testFilesPortListsProjectFoldersAndHidesNativeDocuments() async throws {
        let list = #"{"files":[{"id":"f1","name":"H","mimeType":"application\/vnd.google-apps.folder"},{"id":"d","name":"n","mimeType":"application\/vnd.google-apps.document"},{"id":"p","name":"p.pdf","mimeType":"application\/pdf"}]}"#
        let files = DriveFilesClient(drive: drive(FakeHttp { _ in (200, list) }), projectsRoot: "root")
        let folders = try await files.projectFolders()
        let entries = try await files.files(in: "f1")
        let data = try await files.read("p")
        XCTAssertEqual(folders, [FileFolder(id: "f1", name: "H")])
        XCTAssertEqual(entries.map(\.id), ["f1", "p"])
        XCTAssertEqual(entries.map(\.isFolder), [true, false])
        XCTAssertEqual(data, Data(list.utf8))
    }

    func testTextIsExtractedPerMimeTypeAndTruncated() async throws {
        let reader = DriveTextClient(drive: FakeDrive(tree: [:]))
        let document = try await reader.text(of: file("1", "d", "application/vnd.google-apps.document"))
        let sheet = try await reader.text(of: file("2", "s", "application/vnd.google-apps.spreadsheet"))
        let plain = try await reader.text(of: file("3", "t", "text/plain"))
        let binary = try await reader.text(of: file("4", "b", "application/zip"))
        XCTAssertEqual(document, "text/plain 1")
        XCTAssertEqual(sheet, "text/csv 2")
        XCTAssertEqual(plain, "raw 3")
        XCTAssertNil(binary)
        let long = DriveTextClient(drive: LongDrive())
        let clipped = try await long.text(of: file("5", "t", "text/plain"))
        XCTAssertEqual(clipped?.count, DriveTextClient.maxCharacters + DriveTextClient.truncationMark.count)
        XCTAssertTrue(clipped?.hasSuffix(DriveTextClient.truncationMark) == true)
        let blank = try await DriveTextClient(drive: BlankDrive()).text(of: file("6", "t", "text/plain"))
        XCTAssertNil(blank)
    }

    func testFindFileSearchesBreadthFirstAndStopsAtTheDepthLimit() async throws {
        var tree: [String: [DriveFile]] = ["root": [file("a", "Notes", folder), file("n", "other.txt", "text/plain")]]
        tree["a"] = [file("b", "Deep", folder), file("hit", "Questionnaire 1.pdf")]
        tree["b"] = [file("c", "Deeper", folder)]
        tree["c"] = [file("d", "D", folder)]
        tree["d"] = [file("e", "E", folder)]
        tree["e"] = [file("f", "F", folder)]
        tree["f"] = [file("far", "questionnaire far.pdf")]
        let reader = DriveTextClient(drive: FakeDrive(tree: tree))
        let found = try await reader.findFile(named: " QUESTIONNAIRE ", in: "root")
        XCTAssertEqual(found?.id, "hit")
        tree["a"] = [file("b", "Deep", folder)]
        let deep = try await DriveTextClient(drive: FakeDrive(tree: tree)).findFile(named: "far", in: "root")
        XCTAssertNil(deep)
        let blank = try await reader.findFile(named: "  ", in: "root")
        XCTAssertNil(blank)
    }

    func testOffersAreClassifiedFromFolderPrefixAndName() {
        func type(_ name: String, incoming: Bool = false, folder: String? = nil) -> OfferDocumentType {
            OfferClassificationEngine.classify(file("1", name), isIncoming: incoming, folderName: folder, convention: convention).type
        }
        XCTAssertEqual(type("AN-2026-0001.pdf"), .offer)
        XCTAssertEqual(type("AB-1.pdf"), .orderConfirmation)
        XCTAssertEqual(type("x.pdf", folder: "Invoices"), .finalInvoice)
        XCTAssertEqual(type("TR-1.pdf", folder: "invoice"), .depositInvoice)
        XCTAssertEqual(type("SR-1.pdf", folder: "invoice"), .finalInvoice)
        XCTAssertEqual(type("x.pdf", folder: "offer"), .offer)
        XCTAssertEqual(type("x.pdf", folder: "order"), .orderConfirmation)
        XCTAssertEqual(type("zzz.pdf"), .other)
        XCTAssertEqual(type("x.pdf", incoming: true), .incomingOffer)
        XCTAssertEqual(type("BE-1.pdf", incoming: true), .purchaseOrder)
        XCTAssertEqual(type("x.pdf", incoming: true, folder: "Purchase"), .purchaseOrder)
        let classified = OfferClassificationEngine.classify(file("1", "an_2026-0042_Kd-77_v3.pdf"), isIncoming: false, folderName: nil, convention: convention)
        XCTAssertEqual(classified.documentNumber, "2026-0042")
        XCTAssertEqual(classified.customerNumber, "77")
        XCTAssertEqual(classified.version, "v3")
        XCTAssertEqual(OfferClassificationEngine.prefix(of: "ab-1.pdf"), "AB")
        XCTAssertEqual(OfferDocumentType.allCases.count, 7)
        XCTAssertEqual(OfferDocumentType.offer.labelKey, "google.offer.type.offer")
        XCTAssertEqual(try JSONDecoder().decode(OfferConvention.self, from: JSONEncoder().encode(convention)), convention)
    }

    func testOnlyOfferLikeFileTypesAreAccepted() {
        XCTAssertTrue(OfferEngine.isAcceptedFileType(file("1", "a.PDF")))
        XCTAssertTrue(OfferEngine.isAcceptedFileType(file("1", "mail.eml", "message/rfc822")))
        XCTAssertTrue(OfferEngine.isAcceptedFileType(file("1", "scan", "image/png")))
        XCTAssertTrue(OfferEngine.isAcceptedFileType(file("1", "noext", "application/pdf")))
        XCTAssertFalse(OfferEngine.isAcceptedFileType(file("1", "noext", "text/plain")))
        XCTAssertFalse(OfferEngine.isAcceptedFileType(file("1", "a.docx")))
        XCTAssertFalse(OfferEngine.isAcceptedFileType(file("1", "a.pdf", folder)))
    }

    func testOfferScanFindsTheFoldersAndClassifiesTheirFiles() async throws {
        let tree: [String: [DriveFile]] = [
            "root": [file("misc", "misc", folder), file("o", "outgoing x", folder)],
            "misc": [file("i", "incoming y", folder)],
            "o": [file("a", "AN-2026-0001.pdf"), file("n", "notes.docx", "text/plain"), file("s", "sub", folder)],
            "s": [file("b", "x.pdf")],
            "i": [file("c", "BE-9.pdf")],
        ]
        let result = try await OfferScanEngine.load(rootFolderID: "root", drive: FakeDrive(tree: tree), convention: convention)
        XCTAssertEqual(result.outgoing.map(\.file.id), ["a", "b"])
        XCTAssertEqual(result.outgoing.map(\.type), [.offer, .other])
        XCTAssertEqual(result.outgoing.first?.documentNumber, "2026-0001")
        XCTAssertEqual(result.incoming.map(\.type), [.purchaseOrder])
        let none = try await OfferScanEngine.load(rootFolderID: "empty", drive: FakeDrive(tree: [:]), convention: convention)
        XCTAssertEqual(none, OfferScanResult(incoming: [], outgoing: []))
        let shallow = try await OfferScanEngine.load(rootFolderID: "root", drive: FakeDrive(tree: tree), convention: convention, maxDepth: 0)
        XCTAssertEqual(shallow.incoming, [])
    }

    func testDrivePortMapsEntriesOffersAndText() async throws {
        let tree: [String: [DriveFile]] = [
            "root": [file("o", "outgoing", folder), file("t", "t.txt", "text/plain")],
            "o": [file("a", "AN-2026-0001.pdf")],
        ]
        let port = DriveListingClient(drive: FakeDrive(tree: tree), offers: convention)
        let entries = try await port.list(folderID: "root")
        XCTAssertEqual(entries.map(\.typeLabel), ["google.drive.type.folder", "PLAIN"])
        XCTAssertEqual(entries[0].isFolder, true)
        let listing = try await port.offers(folderID: "root")
        XCTAssertEqual(listing.outgoing.first?.documentNumber, "2026-0001")
        XCTAssertEqual(listing.outgoing.first?.typeLabel, "google.offer.type.offer")
        let found = try await port.findFile(named: "t.txt", in: "root")
        XCTAssertEqual(found?.id, "t")
        let text = try await port.text(of: try XCTUnwrap(found))
        XCTAssertEqual(text, "raw t")
    }

    func testRouterDeliversTheRequestedAdaptersPerCapability() async throws {
        let http = FakeHttp { call in
            call.path.hasSuffix("/labels") ? (200, #"{"labels":[{"id":"L","name":"Eins","type":"user"}]}"#)
                : (200, #"{"files":[{"id":"f1","name":"H","mimeType":"application\/vnd.google-apps.folder"}]}"#)
        }
        let google = router(http)
        XCTAssertEqual(google.id, "google")
        XCTAssertEqual(google.capabilities, [.mail, .calendar, .contacts, .files])
        XCTAssertEqual(google.offers(personal: .person("p")).count, 1)
        let mail = try google.adapter((any MailTransportPort).self, for: inlet([.mail]), grant(), renewal: .ignoring)
        let folders = try await mail.listFolders()
        XCTAssertEqual(folders.last?.id, "L")
        XCTAssertNotNil(try? google.adapter((any GmailPort).self, for: inlet([.mail]), grant(), renewal: .ignoring))
        XCTAssertNotNil(try? google.adapter((any MailSearchPort).self, for: inlet([.mail]), grant(), renewal: .ignoring))
        let files = try google.adapter((any FilesPort).self, for: inlet([.files]), grant(), renewal: .ignoring)
        let projects = try await files.projectFolders()
        XCTAssertEqual(projects.map(\.id), ["f1"])
        XCTAssertNotNil(try? google.adapter((any Assistant.DrivePort).self, for: inlet([.files]), grant(), renewal: .ignoring))
        XCTAssertNotNil(try? google.adapter((any CalendarPort).self, for: inlet([.calendar]), grant(), renewal: .ignoring))
        XCTAssertNotNil(try? google.adapter((any GoogleContactsPort).self, for: inlet([.contacts]), grant(), renewal: .ignoring))
    }

    func testRouterRefusesPortsWithoutTheCapabilityAndUnknownPorts() {
        let google = router(FakeHttp())
        XCTAssertThrowsError(try google.adapter((any FilesPort).self, for: inlet([.mail]), grant(), renewal: .ignoring)) {
            XCTAssertEqual($0 as? HubFailure, .capabilityMissing("g", .files))
        }
        XCTAssertThrowsError(try google.adapter((any CalendarPort).self, for: inlet([.mail]), grant(), renewal: .ignoring)) {
            XCTAssertEqual($0 as? HubFailure, .capabilityMissing("g", .calendar))
        }
        XCTAssertThrowsError(try google.adapter((any ChangePort).self, for: inlet([.mail]), grant(), renewal: .ignoring)) {
            XCTAssertEqual($0 as? HubFailure, .capabilityMissing("g", .mail))
        }
        XCTAssertThrowsError(try google.adapter((any FilesPort).self, for: inlet([.files]), Grant(values: [:]), renewal: .ignoring)) {
            XCTAssertEqual($0 as? SignInFailure, .grantIncomplete(TokenState.accessKey))
        }
    }

    func testRouterAdaptersRefreshAndReportTheRenewal() async throws {
        let renewed = Locked<[Grant]>([])
        let http = FakeHttp { call in
            call.path == "/token" ? (200, #"{"access_token":"fresh","expires_in":3600}"#) : (200, #"{"labels":[]}"#)
        }
        let google = router(http)
        let mail = try google.adapter((any MailTransportPort).self, for: inlet([.mail]), grant(expiresIn: 0), renewal: GrantRenewal(
            renewed: { grant in renewed.with { $0.append(grant) } }, failed: { _ in }))
        _ = try await mail.listFolders()
        XCTAssertEqual(renewed.with { $0 }.first?.values[TokenState.accessKey], "fresh")
        XCTAssertEqual(http.calls.last?.authorization, "Bearer fresh")
        XCTAssertEqual(google.classify(GoogleFailure.notConnected(.gmail)).kind, .transient)
    }

    func testRouterSignInUsesTheGivenSignInPort() async throws {
        struct Given: SignInPort {
            func signIn(_ inlet: Inlet, input: [Field.ID: String]) async throws -> Grant { Grant(values: ["x": "y"]) }
            func renew(_ grant: Grant) async throws -> Grant { grant }
            func signOut(_ inlet: Inlet) async throws {}
        }
        let google = AccessRouter(config: ClientConfig(clientID: "id", clientSecret: ""), drive: driveConfig, http: FakeHttp(),
                                  openBrowser: { _ in true }, makeRedirect: { FakeRedirect { $0 } }, signIn: Given())
        let result = try await google.signIn.signIn(inlet([.mail]), input: [:])
        XCTAssertEqual(result.values, ["x": "y"])
    }

    func testLoopbackReadsOnlyTheRootGetRequest() {
        XCTAssertEqual(OAuthLoopback.redirectURL(from: "GET /?code=a&state=b HTTP/1.1\r\nHost: x\r\n\r\n", port: 5)?.absoluteString,
                       "http://127.0.0.1:5/?code=a&state=b")
        XCTAssertNotNil(OAuthLoopback.redirectURL(from: "GET / HTTP/1.1\r\n\r\n", port: 5))
        XCTAssertNil(OAuthLoopback.redirectURL(from: "POST /?code=a HTTP/1.1\r\n\r\n", port: 5))
        XCTAssertNil(OAuthLoopback.redirectURL(from: "GET /other HTTP/1.1\r\n\r\n", port: 5))
        XCTAssertNil(OAuthLoopback.redirectURL(from: "", port: 5))
    }

    func testFormBodyIsEscapedAndSorted() {
        XCTAssertEqual(String(decoding: FormBodyEngine.encode(["b": "x y&z", "a": "~-._"]), as: UTF8.self), "a=~-._&b=x%20y%26z")
    }
}

private struct LongDrive: Google.DrivePort {
    func listFolder(folderID: String) async throws -> [DriveFile] { [] }
    func fileName(of fileID: String) async throws -> String { "" }
    func downloadContent(fileID: String) async throws -> Data { Data(String(repeating: "a", count: DriveTextClient.maxCharacters + 5).utf8) }
    func exportFile(fileID: String, exportMimeType: String) async throws -> Data { Data() }
    func findOrCreateSubfolder(parentID: String, name: String) async throws -> String { "" }
    func uploadFile(name: String, mimeType: String, data: Data, parentFolderID: String) async throws -> DriveFile { file("", "") }
}

private struct BlankDrive: Google.DrivePort {
    func listFolder(folderID: String) async throws -> [DriveFile] { [] }
    func fileName(of fileID: String) async throws -> String { "" }
    func downloadContent(fileID: String) async throws -> Data { Data("   ".utf8) }
    func exportFile(fileID: String, exportMimeType: String) async throws -> Data { Data() }
    func findOrCreateSubfolder(parentID: String, name: String) async throws -> String { "" }
    func uploadFile(name: String, mimeType: String, data: Data, parentFolderID: String) async throws -> DriveFile { file("", "") }
}
