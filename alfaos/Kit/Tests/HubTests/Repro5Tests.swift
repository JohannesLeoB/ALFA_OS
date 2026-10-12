import Foundation
import GRDB
import Hub
import enum MykilosKit.MailProviderPresets
import class MykilosServices.GoogleOAuthLoopbackRedirectServer
import struct MykilosServices.MailProbeError
import enum MykilosServices.MailTransportError
import protocol MykilosServices.MailTransport
import XCTest

private final class FailingDeleteKeychain: KeychainPort, @unchecked Sendable {
    let inner = FakeKeychain()
    let failOn: String

    init(failOn: String) { self.failOn = failOn }

    func put(_ value: String, at slot: KeySlot) throws { try inner.put(value, at: slot) }
    func get(_ slot: KeySlot) throws -> String? { try inner.get(slot) }
    func delete(_ slot: KeySlot) throws {
        if slot.name == failOn { throw KeychainError.status(-25244) }
        try inner.delete(slot)
    }
}

@MainActor
final class Repro5Tests: XCTestCase {
    static let offer = Offer(id: "imap.mail", provider: IMAPProvider.providerID, title: "GMX", capabilities: [.mail],
                             owner: .person("p1"), way: .form([]))

    private func values(_ address: String = "jo@gmx.example") -> [Field.ID: String] {
        var result = IMAPProviderTests.gmx
        result["address"] = address
        result["username"] = address
        return result
    }

    private func attempt(_ hub: Hub, _ address: String) async -> SetupError? {
        let input = Input.fields(values(address))
        do throws(SetupError) {
            _ = try await hub.setup.add(Self.offer, input: input)
            return nil
        } catch {
            return error
        }
    }

    private func makeHub(
        keychain: any KeychainPort = FakeKeychain(),
        limits: [Capability: Int] = CompanySetup().limits,
        cadence: HandCadence = HandCadence(),
        database: DatabaseQueue? = nil,
        providers: [any Provider]? = nil,
        offers: [Offer]? = nil,
        deadlines: HubDeadlines = .standard,
        run: @escaping IMAPProbeRun = { _, _ in }
    ) throws -> Hub {
        let configuration = HubConfiguration(
            person: Person(id: "p1", name: "P"),
            company: CompanySetup(offers: offers ?? [Self.offer], limits: limits),
            providers: providers ?? [IMAPProvider(probeRun: run)], keychain: keychain, cadence: cadence,
            cost: FakeCost(), catalog: .withMail, database: try database ?? DatabaseQueue(),
            deadlines: deadlines)
        return try Hub.make(configuration)
    }

    func testBug51AddEndsWithTheProbeTimeoutWhenTheProbeNeverReturns() async throws {
        let stuck = try makeHub(deadlines: HubDeadlines(signIn: .seconds(5), probe: .milliseconds(300)),
                                run: { _, _ in try await Task.sleep(for: .seconds(3600)) })
        let error = await attempt(stuck, "jo@gmx.example")
        guard case .probeFailed(let hint)? = error else { return XCTFail("error \(String(describing: error))") }
        XCTAssertEqual(hint.text, "hint.probe.timeout")
        XCTAssertEqual(stuck.setup.inlets, [])
    }

    func testBug52CancelDuringTheProbeIsReportedAsProbeFailed() async throws {
        let stuck = try makeHub(run: { _, _ in try await Task.sleep(for: .seconds(3600)) })
        let task = Task { @MainActor () -> SetupError? in
            do {
                _ = try await stuck.setup.add(Self.offer, input: .fields(values()))
                return nil
            } catch {
                return error as? SetupError
            }
        }
        try await Task.sleep(for: .milliseconds(300))
        task.cancel()
        let error = await task.value
        XCTAssertEqual(error, .cancelled)
    }

    func testBug53ProbeOfAnExistingInletStaysConnectingAndACancelMarksItFailed() async throws {
        let calls = Locked(0)
        let hub = try makeHub(run: { _, _ in
            let number = calls.with { (count: inout Int) -> Int in
                count += 1
                return count
            }
            if number > 1 { try await Task.sleep(for: .seconds(3600)) }
        })
        let inlet = try await hub.setup.add(Self.offer, input: .fields(values()))
        let task = Task { @MainActor in _ = try? await hub.setup.probe(inlet.id) }
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(hub.setup.inlets.first?.state, .connecting)
        task.cancel()
        await task.value
        XCTExpectFailure("BUG-5-3: a cancel leaves a working inlet persisted as failed(CancellationError)") {
            XCTAssertEqual(hub.setup.inlets.first?.state.isConnected, true)
        }
        XCTAssertEqual(hub.setup.inlets.first?.state.canRenew, true)
    }

    func testBug54LimitBlocksRenewalOfTheSameAccount() async throws {
        let accepting = Locked(true)
        let hub = try makeHub(limits: [.mail: 1], run: { _, _ in
            if !accepting.with({ $0 }) { throw MailProbeError(step: .incoming, reason: .authenticationRejected("NO")) }
        })
        let first = try await hub.setup.add(Self.offer, input: .fields(values()))
        accepting.with { $0 = false }
        _ = try? await hub.setup.probe(first.id)
        XCTAssertTrue(hub.setup.inlets[0].state.canRenew)
        accepting.with { $0 = true }
        let seen = await attempt(hub, "jo@gmx.example")
        XCTExpectFailure("BUG-5-4: add checks the limit before it looks for the same account, so a failed account at the limit cannot sign in again") {
            XCTAssertNil(seen)
        }
        XCTAssertEqual(seen, .limitReached(.mail, max: 1))
    }

    func testBug55FailedInletOfAMissingProviderHasNoWayToSignInAgain() async throws {
        let database = try DatabaseQueue()
        let keychain = FakeKeychain()
        let accepting = Locked(true)
        let first = try makeHub(keychain: keychain, database: database, run: { _, _ in
            if !accepting.with({ $0 }) { throw MailProbeError(step: .incoming, reason: .authenticationRejected("NO")) }
        })
        let inlet = try await first.setup.add(Self.offer, input: .fields(values()))
        accepting.with { $0 = false }
        _ = try? await first.setup.probe(inlet.id)
        let restarted = try makeHub(keychain: keychain, database: database, providers: [], offers: [])
        XCTAssertEqual(restarted.setup.inlets.first?.state.canRenew, true)
        XCTExpectFailure("BUG-5-5: the row offers Neu anmelden (canRenew) but renewal(of:) is nil without an offer, the click does nothing") {
            XCTAssertNotNil(restarted.setup.renewal(of: inlet.id))
        }
    }

    func testBug56InletOfAMissingProviderStillReadsConnected() async throws {
        let database = try DatabaseQueue()
        let keychain = FakeKeychain()
        let first = try makeHub(keychain: keychain, database: database)
        let inlet = try await first.setup.add(Self.offer, input: .fields(values()))
        let restarted = try makeHub(keychain: keychain, database: database, providers: [], offers: [])
        XCTAssertThrowsError(try restarted.access.port((any MailTransport).self, for: inlet.id))
        XCTExpectFailure("BUG-5-6: without its provider the inlet is still connected in state and in inlets(for:), though no port can be made") {
            XCTAssertEqual(restarted.access.inlets(for: .mail), [])
        }
        XCTAssertEqual(restarted.setup.inlets.count, 1)
    }

    func testBug59BlankAddressGivesTheGenericFailureHint() async throws {
        let hub = try makeHub()
        var seen: Hint?
        if case .probeFailed(let value)? = await attempt(hub, "") { seen = value }
        XCTExpectFailure("BUG-5-9: the form error hint.imap.fields.invalid is unreachable through add, the user sees hint.provider.failed with a Swift enum text") {
            XCTAssertEqual(seen?.text, "hint.imap.fields.invalid")
        }
        XCTAssertEqual(seen?.text, "hint.provider.failed")
    }

    func testBug510FourthMailAccountIsRefusedByTheBuiltInLimit() async throws {
        let hub = try makeHub()
        for number in 1...3 { _ = try await hub.setup.add(Self.offer, input: .fields(values("u\(number)@gmx.example"))) }
        let seen = await attempt(hub, "u4@gmx.example")
        XCTExpectFailure("BUG-5-10: CompanySetup() carries limits mail 3 in code; the app passes CompanySetup() and nothing calls setLimit") {
            XCTAssertNil(seen)
        }
        XCTAssertEqual(seen, .limitReached(.mail, max: 3))
    }

    func testBug511FailedRemoveStopsTheTimerButKeepsTheInlet() async throws {
        let keychain = FailingDeleteKeychain(failOn: "password")
        let cadence = HandCadence()
        let hub = try makeHub(keychain: keychain, cadence: cadence)
        let inlet = try await hub.setup.add(Self.offer, input: .fields(values()))
        hub.rules.setCadence(inlet.id, .mail, .every(.seconds(60)))
        XCTAssertEqual(cadence.planned(inlet.id, .mail), .every(.seconds(60)))
        do {
            try await hub.setup.remove(inlet.id)
            XCTFail("remove must throw")
        } catch {
        }
        XCTAssertEqual(hub.setup.inlets.count, 1)
        XCTAssertEqual(keychain.inner.slots.count, 2)
        XCTExpectFailure("BUG-5-11: remove cancels the timer and deletes part of the keychain first; on failure the inlet stays connected without a timer and with 2 of 9 items") {
            XCTAssertEqual(cadence.planned(inlet.id, .mail), hub.rules.cadence(inlet.id, .mail))
        }
    }

    func testBug512OneCorruptSettingRowStopsTheWholeHub() throws {
        let database = try DatabaseQueue()
        _ = try makeHub(database: database)
        try database.write { db in
            try db.execute(sql: "INSERT INTO setting (key, value) VALUES ('limit|mail', ?)", arguments: [Data("x".utf8)])
        }
        XCTExpectFailure("BUG-5-12: Hub.make throws for one undecodable settings row; the app then stays in failed with no retry") {
            XCTAssertNotNil(try? makeHub(database: database))
        }
    }

    func testBug513RedirectWaitHasNoDeadlineAndIgnoresCancel() async throws {
        let server = GoogleOAuthLoopbackRedirectServer()
        let ended = Locked(false)
        let task = Task {
            _ = try? await server.awaitRedirect()
            ended.with { $0 = true }
        }
        try await Task.sleep(for: .seconds(1))
        task.cancel()
        try await Task.sleep(for: .seconds(1))
        XCTExpectFailure("BUG-5-13: awaitRedirect has no deadline and no cancel handler; a closed browser tab keeps Google sign-in pending forever") {
            XCTAssertTrue(ended.with { $0 })
        }
        server.stop()
        await task.value
    }

    func testBug514FastmailPresetExistsOnlyAsLiteralInTheHub() {
        XCTAssertTrue(IMAPProvider().presets.contains { $0.id == "fastmail" })
        XCTExpectFailure("BUG-5-14: imap.fastmail.com and smtp.fastmail.com are literals in IMAPProvider.presets, not in the preset table of the fund") {
            XCTAssertTrue(MailProviderPresets.all.contains { $0.id == "fastmail" })
        }
    }

    func testBug515NonSecretFieldsAreKeychainItems() async throws {
        let keychain = FakeKeychain()
        let hub = try makeHub(keychain: keychain)
        _ = try await hub.setup.add(Self.offer, input: .fields(values()))
        XCTAssertEqual(keychain.slots.count, 9)
        XCTExpectFailure("BUG-5-15: address, hosts, ports and security modes are stored as nine keychain items per account, only the password is secret") {
            XCTAssertEqual(keychain.slots.map(\.name), ["password"])
        }
    }
}
