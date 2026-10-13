import Foundation
import GRDB
@testable import Hub
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
final class GoogleRenewalTests: XCTestCase {
    static let offer = Offer(id: "google.mail", provider: "google", title: "Google", capabilities: [.mail],
                             owner: .person("p1"), way: .signIn)

    struct Rig {
        let hub: Hub
        let keychain: FakeKeychain
        let inlet: Inlet
        let clock: Locked<Date>
        let events: Locked<[HubEvent]>
        let collector: Task<Void, Never>
    }

    func rig(refresh: @escaping @Sendable () -> (Int, Data)) async throws -> Rig {
        let clock = Locked(Date())
        let grant = Grant(values: [
            "accessToken": "old-access",
            "refreshToken": "old-refresh",
            "expiresAt": String(clock.with { $0 }.addingTimeInterval(3600).timeIntervalSince1970)
        ])
        GoogleStubNet.install { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/token") { return refresh() }
            if path.hasSuffix("/userinfo") { return (200, Data(#"{"email":"a@example.test"}"#.utf8)) }
            if path.hasSuffix("/labels") { return (200, Data(#"{"labels":[{"id":"INBOX","name":"INBOX","type":"system"}]}"#.utf8)) }
            return (404, Data())
        }
        let keychain = FakeKeychain()
        let provider = GoogleProvider(
            config: GoogleClientConfig(clientID: "id", clientSecret: "secret"), openBrowser: { _ in false },
            session: GoogleStubNet.session(),
            signIn: GivenSignIn(grant: grant),
            clock: { clock.with { $0 } }
        )
        let hub = try Hub.make(HubConfiguration(
            person: Person(id: "p1", name: "P"), company: CompanySetup(offers: [Self.offer]),
            providers: [provider], keychain: keychain, cadence: HandCadence(), cost: FakeCost(),
            catalog: .withMail, database: try DatabaseQueue()
        ))
        let inlet = try await hub.setup.add(Self.offer)
        let events = Locked<[HubEvent]>([])
        let stream = hub.access.events
        let collector = Task { for await event in stream { events.with { $0.append(event) } } }
        clock.with { $0 = $0.addingTimeInterval(7200) }
        return Rig(hub: hub, keychain: keychain, inlet: inlet, clock: clock, events: events, collector: collector)
    }

    func waitUntil(_ condition: @escaping () -> Bool) async throws {
        var attempts = 0
        while attempts < 400 {
            if condition() { break }
            try await Task.sleep(for: .milliseconds(5))
            attempts += 1
        }
        let reached = condition()
        XCTAssertTrue(reached)
    }

    func testGreenRenewalWritesTheNewGrantIntoTheSlotsOfThisInlet() async throws {
        let rig = try await rig { (200, Data(#"{"access_token":"new-access","expires_in":3600}"#.utf8)) }
        defer { rig.collector.cancel() }
        let slot = KeySlot(inlet: rig.inlet.id, name: "accessToken")
        XCTAssertEqual(try rig.keychain.get(slot), "old-access")
        let transport = try rig.hub.access.port(MailTransport.self, for: rig.inlet.id)
        _ = try await transport.listFolders()
        try await waitUntil { (try? rig.keychain.get(slot)) == "new-access" }
        XCTAssertEqual(try rig.keychain.get(KeySlot(inlet: rig.inlet.id, name: "refreshToken")), "old-refresh")
        XCTAssertEqual(Set(rig.keychain.slots.map(\.inlet)), [rig.inlet.id])
        try await waitUntil { rig.events.with { $0.contains(.inletChanged(rig.inlet.id)) } }
        guard case .connected = rig.hub.setup.inlets[0].state else { return XCTFail("state") }
    }

    func testRedRenewalMarksTheInletExpiredAndPortThrows() async throws {
        let rig = try await rig { (400, Data()) }
        defer { rig.collector.cancel() }
        let transport = try rig.hub.access.port(MailTransport.self, for: rig.inlet.id)
        do {
            _ = try await transport.listFolders()
            XCTFail("listFolders must throw")
        } catch {
        }
        try await waitUntil {
            if case .failed(let hint) = rig.hub.setup.inlets[0].state { return hint.text == "hint.signin.expired" }
            return false
        }
        try await waitUntil { rig.events.with { $0.contains(.inletChanged(rig.inlet.id)) } }
        XCTAssertThrowsError(try rig.hub.access.port(MailTransport.self, for: rig.inlet.id)) {
            XCTAssertEqual($0 as? HubError, .notConnected(rig.inlet.id))
        }
    }

    func testServerOutageDuringRenewalKeepsTheInletConnected() async throws {
        let rig = try await rig { (503, Data()) }
        defer { rig.collector.cancel() }
        let transport = try rig.hub.access.port(MailTransport.self, for: rig.inlet.id)
        do {
            _ = try await transport.listFolders()
            XCTFail("listFolders must throw")
        } catch {
        }
        try await Task.sleep(for: .milliseconds(50))
        guard case .connected = rig.hub.setup.inlets[0].state else { return XCTFail("state \(rig.hub.setup.inlets[0].state)") }
        XCTAssertEqual(try rig.keychain.get(KeySlot(inlet: rig.inlet.id, name: "accessToken")), "old-access")
        _ = try rig.hub.access.port(MailTransport.self, for: rig.inlet.id)
    }

    // Nachbauten und Pins zur Erneuerung des Google-Tokens (BUG-3-14 bis BUG-3-17).

    func testSyncAfterServerOutageOnRenewalKeepsTheInletConnected() async throws {
        let rig = try await scriptedGoogleRig(token: { (503, Data()) })
        await rig.cadence.trigger(rig.inlet.id, .mail)
        let state = rig.hub.setup.inlets[0].state
        guard case .connected = state else { return XCTFail("state \(state)") }
    }

    func testBug15TokenFailureIsMaskedAsNotConnected() async throws {
        let rig = try await scriptedGoogleRig(token: { (503, Data()) })
        await rig.cadence.trigger(rig.inlet.id, .mail)
        let detail = rig.hub.setup.inlets[0].state.hint?.detail ?? ""
        XCTExpectFailure("BUG-3-15: GoogleGmailClient maps every token error with try? to .notConnected; the 503 is lost") {
            XCTAssertTrue(detail.contains("503"), "hint detail: \(detail)")
        }
    }

    func testBug16ProbeDiscardsTheRenewedToken() async throws {
        let rig = try await scriptedGoogleRig(token: { (200, Data(#"{"access_token":"new-access","expires_in":3600}"#.utf8)) })
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
}
