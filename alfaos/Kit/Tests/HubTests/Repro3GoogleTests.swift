import Foundation
import GRDB
@testable import Hub
import enum MykilosServices.GoogleGmailError
import protocol MykilosServices.GoogleTokenRefreshing
import struct MykilosServices.GoogleOAuthTokenExchangeResponse
import protocol MykilosServices.MailTransport
import XCTest

private final class GateRefresher: GoogleTokenRefreshing, @unchecked Sendable {
    let gate = Gate()
    let calls = Locked(0)

    func refresh(refreshToken: String, clientID: String, clientSecret: String?) async throws -> GoogleOAuthTokenExchangeResponse {
        calls.with { $0 += 1 }
        await gate.wait()
        return try JSONDecoder().decode(GoogleOAuthTokenExchangeResponse.self,
                                        from: Data(#"{"access_token":"fresh","expires_in":3600}"#.utf8))
    }
}

@MainActor
final class Repro3GoogleTests: XCTestCase {
    private let listJSON = Data(#"{"messages":[{"id":"m1"},{"id":"m2"}]}"#.utf8)
    private let detailJSON = Data(#"{"id":"m1","threadId":"t1","snippet":"s","payload":{"headers":[]},"labelIds":["INBOX"],"internalDate":"1"}"#.utf8)

    func testBug14ServerOutageOnRenewalStillTurnsTheInletFailedThroughSync() async throws {
        let rig = try await repro3GoogleRig(token: { (503, Data()) })
        await rig.cadence.trigger(rig.inlet.id, .mail)
        let state = rig.hub.setup.inlets[0].state
        guard case .connected = state else { return XCTFail("state \(state)") }
    }

    func testBug15TokenFailureIsMaskedAsNotConnected() async throws {
        let rig = try await repro3GoogleRig(token: { (503, Data()) })
        await rig.cadence.trigger(rig.inlet.id, .mail)
        let detail = rig.hub.setup.inlets[0].state.hint?.detail ?? ""
        XCTExpectFailure("BUG-3-15: GoogleGmailClient maps every token error with try? to .notConnected; the 503 is lost") {
            XCTAssertTrue(detail.contains("503"), "hint detail: \(detail)")
        }
    }

    func testBug16ProbeDiscardsTheRenewedToken() async throws {
        let rig = try await repro3GoogleRig(token: { (200, Data(#"{"access_token":"new-access","expires_in":3600}"#.utf8)) })
        _ = try await rig.hub.setup.probe(rig.inlet.id)
        try await Task.sleep(for: .milliseconds(100))
        let stored = try rig.keychain.get(KeySlot(inlet: rig.inlet.id, name: "accessToken"))
        XCTExpectFailure("BUG-3-16: GoogleProbe builds its token provider with GrantRenewal.ignoring; the refreshed grant is never written") {
            XCTAssertEqual(stored, "new-access")
        }
    }

    func testBug17ConcurrentCallsRefreshTheTokenTwice() async throws {
        let refresher = GateRefresher()
        let now = Date()
        let tokens = GoogleGrantTokenProvider(
            state: GoogleTokenState(accessToken: "old", refreshToken: "r", expiresAt: now.addingTimeInterval(-10)),
            config: GoogleClientConfig(clientID: "i", clientSecret: "s"), refresher: refresher, clock: { now })
        let first = Task { try await tokens.validAccessToken() }
        let second = Task { try await tokens.validAccessToken() }
        for _ in 0..<100 where refresher.calls.with({ $0 }) < 2 { try await Task.sleep(for: .milliseconds(5)) }
        await refresher.gate.release()
        _ = try await first.value
        _ = try await second.value
        let calls = refresher.calls.with { $0 }
        XCTExpectFailure("BUG-3-17: validAccessToken has no single flight; two callers with an expired token send two refresh requests") {
            XCTAssertEqual(calls, 1)
        }
    }

    func testBug18FailedDetailFetchDropsTheMessageWithoutAnError() async throws {
        let list = listJSON
        let detail = detailJSON
        let rig = try await repro3GoogleRig(token: { (200, Data()) }, other: { path in
            if path.hasSuffix("/messages") { return (200, list) }
            if path.hasSuffix("/messages/m1") { return (200, detail) }
            if path.hasSuffix("/messages/m2") { return (500, Data()) }
            return nil
        }, expire: false)
        let transport = try rig.hub.access.port(MailTransport.self, for: rig.inlet.id)
        do {
            let page = try await transport.listMessages(folderID: "INBOX", query: nil, pageToken: nil, maxResults: 10)
            XCTAssertEqual(page.messages.map(\.id), ["m1", "m2"])
        } catch GoogleGmailError.api(let fault) {
            XCTAssertEqual(fault.status, 500)
        }
    }

    func testBug19MissingSubjectBecomesAGermanPlaceholderFromCode() async throws {
        let list = listJSON
        let detail = detailJSON
        let rig = try await repro3GoogleRig(token: { (200, Data()) }, other: { path in
            if path.hasSuffix("/messages") { return (200, list) }
            if path.hasSuffix("/messages/m1") { return (200, detail) }
            if path.hasSuffix("/messages/m2") { return (200, detail) }
            return nil
        }, expire: false)
        let transport = try rig.hub.access.port(MailTransport.self, for: rig.inlet.id)
        let page = try await transport.listMessages(folderID: "INBOX", query: nil, pageToken: nil, maxResults: 10)
        let subject = page.messages.first?.subject
        XCTExpectFailure("BUG-3-19: GoogleGmailClient.mapResource writes the visible text \"(kein Betreff)\" into the data") {
            XCTAssertEqual(subject, "")
        }
    }
}
