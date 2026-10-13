import Foundation
import GRDB
import Hub
import enum MykilosServices.MailTransportError
import protocol MykilosServices.MailTransport
import XCTest

@MainActor
final class HubStateTests: XCTestCase {
    func testBug1SyncErrorTurnsInletFailedAndStopsAutoSync() async throws {
        let rig = try ScriptedRig.make()
        let inlet = try await rig.connect("a@x")
        rig.hub.rules.setCadence(inlet.id, .mail, .every(.seconds(300)))
        rig.provider.mail.setFailure(.connectionFailed("offline"))
        await rig.cadence.trigger(inlet.id, .mail)
        rig.provider.mail.setFailure(nil)
        await rig.cadence.trigger(inlet.id, .mail)
        let stock = rig.hub.access.stock(.mailboxes, as: MailboxRecord.self)
        let state = rig.hub.setup.inlets[0].state
        XCTAssertTrue(state.isConnected, "state after the next tick: \(state)")
        XCTAssertEqual(stock.items.map(\.name), ["Inbox"])
    }

    func testBug2SecondCapabilityLeavesInletStuckOnWorking() async throws {
        let mailGate = Gate()
        let calendarGate = Gate()
        var catalog = PortCatalog.withMail
        catalog.register(CalendarPort.self, capability: .calendar, sync: { _, _ in
            await calendarGate.wait()
            return SyncOutcome()
        })
        let rig = try ScriptedRig.make(capabilities: [.mail, .calendar], offer: ScriptedRig.bothOffer, catalog: catalog)
        let inlet = try await rig.connect("a@x", offer: ScriptedRig.bothOffer)
        rig.provider.mail.setGate(mailGate)
        let mail = Task { @MainActor in await rig.cadence.trigger(inlet.id, .mail) }
        _ = await eventually { rig.provider.mail.listFoldersCalls == 1 }
        let calendar = Task { @MainActor in await rig.cadence.trigger(inlet.id, .calendar) }
        let both = await eventually { rig.hub.rules.queue.count == 2 }
        XCTAssertTrue(both)
        await mailGate.release()
        await mail.value
        await calendarGate.release()
        await calendar.value
        let state = rig.hub.setup.inlets[0].state
        XCTExpectFailure("BUG-3-2: the second overlapping sync saves .working as its previous state and restores it") {
            guard case .connected = state else { return XCTFail("final state \(state)") }
        }
    }

    func testBug3FinishingSyncOverwritesFailureOfParallelSync() async throws {
        let mailGate = Gate()
        var catalog = PortCatalog.withMail
        catalog.register(CalendarPort.self, capability: .calendar, sync: { _, _ in throw CalendarDown() })
        let rig = try ScriptedRig.make(capabilities: [.mail, .calendar], offer: ScriptedRig.bothOffer, catalog: catalog)
        let inlet = try await rig.connect("a@x", offer: ScriptedRig.bothOffer)
        rig.provider.mail.setGate(mailGate)
        let mail = Task { @MainActor in await rig.cadence.trigger(inlet.id, .mail) }
        _ = await eventually { rig.provider.mail.listFoldersCalls == 1 }
        await rig.cadence.trigger(inlet.id, .calendar)
        guard case .failed = rig.hub.setup.inlets[0].state else { return XCTFail("calendar failure not recorded") }
        await mailGate.release()
        await mail.value
        let state = rig.hub.setup.inlets[0].state
        XCTExpectFailure("BUG-3-3: a sync that finishes later restores its captured previous state and erases the newer failed state (memory shows connected, disk shows failed)") {
            guard case .failed = state else { return XCTFail("state after mail sync finished: \(state)") }
        }
    }

    func testBug4RenewalDuringSyncPersistsWorkingStateAndItSticksAfterRestart() async throws {
        let database = try DatabaseQueue()
        let gate = Gate()
        let keychain = FakeKeychain()
        let offer = Offer(id: "ren.mail", provider: "ren", title: "Ren", capabilities: [.mail],
                          owner: .person("p1"), way: .signIn)
        let provider = ScriptedProvider(
            id: "ren", capabilities: [.mail], signIn: SlotsSignIn(values: ["token": "first"]),
            probe: AcceptingProbe(account: "r@x"),
            make: { _, _, renewal in RenewingTransport(renewal: renewal, gate: gate) })
        let cadence = HandCadence()
        let hub = try scriptedHub(providers: [provider], offer: offer, keychain: keychain, cadence: cadence,
                                database: database)
        let inlet = try await hub.setup.add(offer)
        let slot = KeySlot(inlet: inlet.id, name: "token")
        let sync = Task { @MainActor in await cadence.trigger(inlet.id, .mail) }
        let adopted = await eventually { (try? keychain.get(slot)) == "renewed" }
        XCTAssertTrue(adopted)
        let row = try await database.read { try Data.fetchOne($0, sql: "SELECT json FROM inlet WHERE id = ?", arguments: [inlet.id]) }
        let persisted = try JSONDecoder().decode(Inlet.self, from: try XCTUnwrap(row))
        await gate.release()
        await sync.value
        let restarted = try scriptedHub(providers: [provider], offer: offer, keychain: keychain,
                                      cadence: HandCadence(), database: database)
        let reloaded = restarted.setup.inlets[0].state
        XCTExpectFailure("BUG-3-4: adopt saves the inlet while its state is .working; after a restart the probe date is gone") {
            XCTAssertNotEqual(persisted.state, .working)
        }
        XCTExpectFailure("BUG-3-4: adopt saves the inlet while its state is .working; after a restart the probe date is gone") {
            XCTAssertNotNil(reloaded.probed, "reloaded state \(reloaded)")
        }
    }

    func testBug5ReprobeOfFailedInletAfterRestartDoesNotPlanTheCadenceAgain() async throws {
        let rig = try ScriptedRig.make()
        let inlet = try await rig.connect("a@x")
        rig.hub.rules.setCadence(inlet.id, .mail, .every(.seconds(300)))
        rig.provider.mail.setFailure(.serverRejected("NO denied"))
        await rig.cadence.trigger(inlet.id, .mail)
        rig.provider.mail.setFailure(nil)
        let again = try ScriptedRig.make(database: rig.database, provider: rig.provider, keychain: rig.keychain)
        XCTAssertNil(again.cadence.planned(inlet.id, .mail))
        _ = try await again.hub.setup.probe(inlet.id)
        XCTAssertTrue(again.hub.setup.inlets[0].state.isConnected)
        XCTExpectFailure("BUG-3-5: probe() sets connected but never plans the stored cadence; no timer until the next app start") {
            XCTAssertEqual(again.cadence.planned(inlet.id, .mail), .every(.seconds(300)))
        }
    }

    func testBug6SyncWithUnreadableKeychainIsSkippedSilentlyWhileInletStaysConnected() async throws {
        let rig = try ScriptedRig.make()
        let inlet = try await rig.connect("a@x")
        let again = try ScriptedRig.make(database: rig.database, provider: rig.provider, keychain: FakeKeychain())
        await again.cadence.trigger(inlet.id, .mail)
        let state = again.hub.setup.inlets[0].state
        XCTExpectFailure("BUG-3-6: runSync returns .skipped for a missing grant; the state stays connected, only port() flips it to keychainUnreadable") {
            XCTAssertEqual(state, .keychainUnreadable)
        }
    }

    func testBug7ConcurrentRefreshLeavesStockOnLoading() async throws {
        let rig = try ScriptedRig.make()
        _ = try await rig.connect("a@x")
        let stock = rig.hub.access.stock(.messages, as: MailboxRecord.self)
        let gate = Gate()
        rig.provider.mail.setGate(gate)
        let first = Task { @MainActor in await stock.refresh() }
        _ = await eventually { rig.provider.mail.listFoldersCalls == 1 }
        await stock.refresh()
        await gate.release()
        await first.value
        XCTExpectFailure("BUG-3-7: begin() of the second refresh overwrites the saved state with .loading; end() of the first has nothing to restore") {
            XCTAssertEqual(stock.state, .empty)
        }
    }

    func testBug9SettingWriteErrorIsSwallowed() async throws {
        let rig = try ScriptedRig.make()
        let inlet = try await rig.connect("a@x")
        try await rig.database.write {
            try $0.execute(sql: "CREATE TRIGGER no_setting BEFORE INSERT ON setting BEGIN SELECT RAISE(ABORT, 'disk full'); END")
        }
        rig.hub.rules.setCadence(inlet.id, .mail, .every(.seconds(60)))
        rig.hub.rules.setLimit(.mail, 9)
        rig.hub.rules.setTruth(.mailboxes, inlet.id)
        XCTAssertEqual(rig.hub.rules.cadence(inlet.id, .mail), .every(.seconds(60)))
        let again = try ScriptedRig.make(database: rig.database, provider: rig.provider, keychain: rig.keychain)
        XCTExpectFailure("BUG-3-9: persist() uses try?; memory and disk diverge without any report") {
            XCTAssertEqual(again.hub.rules.cadence(inlet.id, .mail), .every(.seconds(60)))
        }
        XCTExpectFailure("BUG-3-9: persist() uses try?; memory and disk diverge without any report") {
            XCTAssertEqual(again.hub.rules.limit(.mail), 9)
        }
        XCTExpectFailure("BUG-3-9: persist() uses try?; memory and disk diverge without any report") {
            XCTAssertEqual(again.hub.rules.truth(.mailboxes), inlet.id)
        }
    }

    func testBug10DatabaseFailureInAddIsReportedAsKeychainError() async throws {
        let rig = try ScriptedRig.make()
        try await rig.database.write {
            try $0.execute(sql: "CREATE TRIGGER no_inlet BEFORE INSERT ON inlet BEGIN SELECT RAISE(ABORT, 'disk full'); END")
        }
        var observed: SetupError?
        do throws(SetupError) {
            _ = try await rig.connect("a@x")
        } catch {
            observed = error
        }
        XCTAssertNotNil(observed)
        XCTAssertTrue(rig.keychain.slots.isEmpty)
        XCTExpectFailure("BUG-3-10: store.save errors are mapped to SetupError.keychain(-1)") {
            XCTAssertNotEqual(observed, SetupError.keychain(-1))
        }
    }
}
