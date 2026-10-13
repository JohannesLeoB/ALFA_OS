import XCTest
@testable import MykilosServices

private final class LabelsStub: URLProtocol {
    nonisolated(unsafe) static var body = Data()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private struct FixedToken: GoogleAccessTokenProviding {
    func validAccessToken() async throws -> String { "token" }
}

private final class LabelCountingStub: URLProtocol {
    nonisolated(unsafe) static var labelCalls = 0
    private static let lock = NSLock()

    static func reset() { lock.withLock { labelCalls = 0 } }
    static var calls: Int { lock.withLock { labelCalls } }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let path = request.url?.path ?? ""
        let body: String
        if path.hasSuffix("/labels") {
            Self.lock.withLock { Self.labelCalls += 1 }
            body = #"{"labels":[{"id":"Label_1","name":"Work","type":"user"}]}"#
        } else if path.hasSuffix("/messages") {
            body = #"{"messages":[{"id":"m1"}],"nextPageToken":"next"}"#
        } else {
            let headers = #"[{"name":"Subject","value":"S"},{"name":"From","value":"a@x.test"}]"#
            body = "{\"id\":\"m1\",\"threadId\":\"t\",\"snippet\":\"s\",\"labelIds\":[\"INBOX\"],\"payload\":{\"headers\":\(headers)}}"
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}

final class GmailFoldersTests: XCTestCase {
    func testSystemFoldersCarryRolesAndUserLabelsFollow() async throws {
        LabelsStub.body = Data(#"""
        {"labels":[
          {"id":"INBOX","name":"INBOX","type":"system"},
          {"id":"SENT","name":"SENT","type":"system"},
          {"id":"Label_1","name":"Projekte","type":"user"},
          {"id":"Label_2","name":"Archiv","type":"user"}
        ]}
        """#.utf8)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LabelsStub.self]
        let client = GoogleGmailClient(tokenProvider: FixedToken(), session: URLSession(configuration: configuration))
        let folders = try await GmailMailTransport(client: client).listFolders()

        XCTAssertEqual(folders.prefix(7).map(\.role), [.inbox, .starred, .sent, .drafts, .all, .spam, .trash])
        XCTAssertEqual(folders.prefix(7).map(\.id), ["INBOX", "STARRED", "SENT", "DRAFT", "ALL", "SPAM", "TRASH"])
        XCTAssertEqual(folders.dropFirst(7).map(\.name), ["Archiv", "Projekte"])
        XCTAssertTrue(folders.dropFirst(7).allSatisfy { $0.role == .other })
    }

    func testEveryPageOfALabelFolderListsTheLabelsOnlyOnce() async throws {
        LabelCountingStub.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LabelCountingStub.self]
        let client = GoogleGmailClient(tokenProvider: FixedToken(), session: URLSession(configuration: configuration))
        let transport = GmailMailTransport(client: client)
        _ = try await transport.listMessages(folderID: "Label_1", query: nil, pageToken: nil, maxResults: 50)
        _ = try await transport.listMessages(folderID: "Label_1", query: nil, pageToken: "next", maxResults: 50)
        let calls = LabelCountingStub.calls
        XCTExpectFailure("BUG-4-23: GmailMailTransport.labelQuery fetches the label list on every page of a label folder (2 calls for 2 pages, one would do)") {
            XCTAssertLessThanOrEqual(calls, 1)
        }
    }
}
