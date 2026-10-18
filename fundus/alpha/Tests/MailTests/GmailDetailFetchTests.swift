import XCTest
@testable import AlfaServices

private struct StubToken: GoogleAccessTokenProviding {
    func validAccessToken() async throws -> String { "token" }
}

private final class DetailStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var lock = NSLock()
    nonisolated(unsafe) static var active = 0
    nonisolated(unsafe) static var peak = 0
    nonisolated(unsafe) static var attempts: [String: Int] = [:]
    nonisolated(unsafe) static var plan: [String: [Int]] = [:]
    nonisolated(unsafe) static var ids: [String] = []

    static func reset(ids: [String], plan: [String: [Int]] = [:]) {
        lock.withLock {
            active = 0
            peak = 0
            attempts = [:]
            self.plan = plan
            self.ids = ids
        }
    }

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DetailStub.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let path = request.url?.path ?? ""
        if path.hasSuffix("/messages") {
            let list = Self.lock.withLock { Self.ids }.map { "{\"id\":\"\($0)\"}" }.joined(separator: ",")
            respond(200, "{\"messages\":[\(list)]}")
            return
        }
        let id = String(path.split(separator: "/").last ?? "")
        let status = Self.lock.withLock { () -> Int in
            Self.active += 1
            Self.peak = max(Self.peak, Self.active)
            let attempt = Self.attempts[id, default: 0]
            Self.attempts[id] = attempt + 1
            let steps = Self.plan[id] ?? []
            return attempt < steps.count ? steps[attempt] : (steps.last == 200 || steps.isEmpty ? 200 : steps.last ?? 200)
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
            Self.lock.withLock { Self.active -= 1 }
            switch status {
            case 200:
                self.respond(200, "{\"id\":\"\(id)\",\"threadId\":\"t\",\"snippet\":\"s\",\"labelIds\":[\"INBOX\"],\"payload\":{\"headers\":[]}}")
            case 403:
                self.respond(403, #"{"error":{"code":403,"message":"Rate Limit Exceeded","errors":[{"domain":"usageLimits","reason":"rateLimitExceeded"}]}}"#)
            case 429:
                self.respond(429, #"{"error":{"code":429,"message":"Too many concurrent requests for user","status":"RESOURCE_EXHAUSTED"}}"#)
            default:
                self.respond(status, "")
            }
        }
    }

    private func respond(_ status: Int, _ body: String) {
        guard let url = request.url, let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil) else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}

final class GmailDetailFetchTests: XCTestCase {
    private func client(_ policy: GmailRequestPolicy) -> GoogleGmailClient {
        GoogleGmailClient(tokenProvider: StubToken(), session: DetailStub.session(), policy: policy)
    }

    func testDetailRequestsRunWithBoundedConcurrency() async throws {
        DetailStub.reset(ids: (1...20).map { "m\($0)" })
        let policy = GmailRequestPolicy(maxConcurrentDetails: 3, maxAttempts: 3, firstDelay: .milliseconds(1))
        let page = try await client(policy).listMessages(query: "", maxResults: 20, pageToken: nil)
        XCTAssertEqual(page.messages.count, 20)
        XCTAssertEqual(page.messages.map(\.id), (1...20).map { "m\($0)" })
        let peak = DetailStub.lock.withLock { DetailStub.peak }
        XCTAssertLessThanOrEqual(peak, 3)
        XCTAssertGreaterThan(peak, 1)
    }

    func testRateLimitedDetailIsRetriedWithBackoffAndSucceeds() async throws {
        DetailStub.reset(ids: ["m1", "m2"], plan: ["m1": [429, 403, 200], "m2": [503, 200]])
        let policy = GmailRequestPolicy(maxConcurrentDetails: 2, maxAttempts: 3, firstDelay: .milliseconds(5))
        let page = try await client(policy).listMessages(query: "", maxResults: 2, pageToken: nil)
        XCTAssertEqual(page.messages.map(\.id), ["m1", "m2"])
        let attempts = DetailStub.lock.withLock { DetailStub.attempts }
        XCTAssertEqual(attempts, ["m1": 3, "m2": 2])
    }

    func testDetailThatKeepsFailingFailsThePageWithTheOriginalError() async throws {
        DetailStub.reset(ids: ["m1", "m2"], plan: ["m2": [429]])
        let policy = GmailRequestPolicy(maxConcurrentDetails: 2, maxAttempts: 3, firstDelay: .milliseconds(1))
        do {
            _ = try await client(policy).listMessages(query: "", maxResults: 2, pageToken: nil)
            XCTFail("the page must fail")
        } catch GoogleGmailError.api(let fault) {
            XCTAssertEqual(fault.status, 429)
            XCTAssertEqual(fault.message, "Too many concurrent requests for user")
            XCTAssertEqual(fault.state, "RESOURCE_EXHAUSTED")
        }
        XCTAssertEqual(DetailStub.lock.withLock { DetailStub.attempts["m2"] }, 3)
    }

    func testNonRetryableDetailErrorIsNotRepeated() async throws {
        DetailStub.reset(ids: ["m1"], plan: ["m1": [404]])
        let policy = GmailRequestPolicy(maxConcurrentDetails: 1, maxAttempts: 3, firstDelay: .milliseconds(1))
        do {
            _ = try await client(policy).listMessages(query: "", maxResults: 1, pageToken: nil)
            XCTFail("the page must fail")
        } catch GoogleGmailError.api(let fault) {
            XCTAssertEqual(fault.status, 404)
        }
        XCTAssertEqual(DetailStub.lock.withLock { DetailStub.attempts["m1"] }, 1)
    }
}
