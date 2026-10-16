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

private final class ModifyCapturingStub: URLProtocol {
    nonisolated(unsafe) static var bodies: [Data] = []
    private static let lock = NSLock()

    static func reset() { lock.withLock { bodies = [] } }
    static var captured: [Data] { lock.withLock { bodies } }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        var body = request.httpBody ?? Data()
        if let stream = request.httpBodyStream {
            stream.open()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                body.append(buffer, count: count)
            }
            stream.close()
        }
        Self.lock.withLock { Self.bodies.append(body) }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
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
    }

    func testMarkingReadRemovesTheUnreadLabelAndMarkingUnreadAddsIt() async throws {
        ModifyCapturingStub.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ModifyCapturingStub.self]
        let client = GoogleGmailClient(tokenProvider: FixedToken(), session: URLSession(configuration: configuration))
        let transport = GmailMailTransport(client: client)
        try await transport.setFlags(messageID: "m1", add: [.seen], remove: [])
        try await transport.setFlags(messageID: "m1", add: [], remove: [.seen])
        let bodies = try ModifyCapturingStub.captured.map { try XCTUnwrap(JSONSerialization.jsonObject(with: $0) as? [String: [String]]) }
        XCTAssertEqual(bodies.count, 2)
        XCTAssertEqual(bodies[0]["removeLabelIds"], ["UNREAD"])
        XCTAssertNil(bodies[0]["addLabelIds"])
        XCTAssertEqual(bodies[1]["addLabelIds"], ["UNREAD"])
        XCTAssertNil(bodies[1]["removeLabelIds"])
    }
}
