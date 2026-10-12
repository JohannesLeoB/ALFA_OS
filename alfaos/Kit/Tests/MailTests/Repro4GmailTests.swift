import Foundation
import protocol MykilosServices.GoogleAccessTokenProviding
import struct MykilosServices.GoogleGmailClient
import struct MykilosServices.GmailMailTransport
import XCTest

struct Repro4Token: GoogleAccessTokenProviding {
    func validAccessToken() async throws -> String { "token" }
}

final class Repro4Stub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var lock = NSLock()
    nonisolated(unsafe) static var active = 0
    nonisolated(unsafe) static var peak = 0
    nonisolated(unsafe) static var labelCalls = 0
    nonisolated(unsafe) static var listIDs: [String] = []
    nonisolated(unsafe) static var failing: Set<String> = []

    static func reset(ids: [String], failing: Set<String> = []) {
        lock.withLock {
            active = 0
            peak = 0
            labelCalls = 0
            listIDs = ids
            Self.failing = failing
        }
    }

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [Repro4Stub.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let path = request.url?.path ?? ""
        if path.hasSuffix("/labels") {
            Self.lock.withLock { Self.labelCalls += 1 }
            respond(200, #"{"labels":[{"id":"Label_1","name":"Work","type":"user"}]}"#)
        } else if path.hasSuffix("/messages") {
            let ids = Self.lock.withLock { Self.listIDs }
            let list = ids.map { "{\"id\":\"\($0)\"}" }.joined(separator: ",")
            respond(200, "{\"messages\":[\(list)],\"nextPageToken\":\"next\"}")
        } else {
            let id = String(path.split(separator: "/").last ?? "")
            Self.lock.withLock {
                Self.active += 1
                Self.peak = max(Self.peak, Self.active)
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
                Self.lock.withLock { Self.active -= 1 }
                if Self.lock.withLock({ Self.failing.contains(id) }) {
                    self.respond(403, #"{"error":{"code":403,"message":"rateLimitExceeded"}}"#)
                } else {
                    let headers = #"[{"name":"Subject","value":"S"},{"name":"From","value":"a@x.test"}]"#
                    self.respond(200, "{\"id\":\"\(id)\",\"threadId\":\"t\",\"snippet\":\"s\",\"labelIds\":[\"INBOX\"],\"payload\":{\"headers\":\(headers)}}")
                }
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

final class Repro4GmailTests: XCTestCase {
    private func transport() -> GmailMailTransport {
        GmailMailTransport(client: GoogleGmailClient(tokenProvider: Repro4Token(), session: Repro4Stub.session()))
    }

    func testOnePageFiresOneDetailRequestPerMessageAtOnce() async throws {
        Repro4Stub.reset(ids: (1...50).map { "m\($0)" })
        let page = try await transport().listMessages(folderID: "INBOX", query: nil, pageToken: nil, maxResults: 50)
        XCTAssertEqual(page.messages.count, 50)
        let peak = Repro4Stub.lock.withLock { Repro4Stub.peak }
        XCTAssertLessThan(peak, 50)
    }

    func testAFailedDetailRequestDropsTheRowWithoutAnError() async throws {
        Repro4Stub.reset(ids: ["m1", "m2", "m3", "m4", "m5"], failing: ["m2", "m4"])
        var count = -1
        do {
            let page = try await transport().listMessages(folderID: "INBOX", query: nil, pageToken: nil, maxResults: 5)
            count = page.messages.count
            XCTAssertEqual(page.nextPageToken, "next")
        } catch {
            count = -1
        }
        XCTAssertTrue(count == 5 || count == -1, "count \(count)")
    }

    func testEveryPageOfALabelFolderListsTheLabelsAgain() async throws {
        Repro4Stub.reset(ids: ["m1"])
        let transport = transport()
        _ = try await transport.listMessages(folderID: "Label_1", query: nil, pageToken: nil, maxResults: 50)
        _ = try await transport.listMessages(folderID: "Label_1", query: nil, pageToken: "next", maxResults: 50)
        let calls = Repro4Stub.lock.withLock { Repro4Stub.labelCalls }
        XCTExpectFailure("BUG-4-23: GmailMailTransport.labelQuery fetches the label list on every page of a label folder (2 calls for 2 pages, one would do)") {
            XCTAssertLessThanOrEqual(calls, 1)
        }
    }
}
