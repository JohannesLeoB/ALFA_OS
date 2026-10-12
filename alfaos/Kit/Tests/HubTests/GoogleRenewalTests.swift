import Foundation
import GRDB
import Hub
import protocol MykilosServices.MailTransport
import XCTest

private struct GivenSignIn: SignInPort {
    let grant: Grant

    func signIn(_ inlet: Inlet, input: [Field.ID: String]) async throws -> Grant { grant }
    func renew(_ grant: Grant) async throws -> Grant { grant }
    func signOut(_ inlet: Inlet) async throws {}
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
}
