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
}
