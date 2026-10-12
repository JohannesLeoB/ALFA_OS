import Foundation
import GRDB
import Hub
@testable import Mail
import enum MykilosServices.MailFolderRole
import struct MykilosServices.MailFolder
import struct MykilosServices.MailMessagePage
import struct MykilosServices.MailMessageSummary
import XCTest

private final class R5Flag: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Bool

    init(_ value: Bool) { current = value }

    var value: Bool {
        get { lock.withLock { current } }
        set { lock.withLock { current = newValue } }
    }
}

private final class R5Keychain: KeychainPort, @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [KeySlot: String] = [:]

    func put(_ value: String, at slot: KeySlot) throws { lock.withLock { entries[slot] = value } }
    func get(_ slot: KeySlot) throws -> String? { lock.withLock { entries[slot] } }
    func delete(_ slot: KeySlot) throws { lock.withLock { entries[slot] = nil } }
}

private final class R5Cadence: CadencePort, @unchecked Sendable {
    let reports = AsyncStream<SyncReport> { _ in }
    func attach(_ runner: @escaping SyncRunner) {}
    func plan(_ inlet: Inlet.ID, _ capability: Capability, _ cadence: Cadence) {}
    func trigger(_ inlet: Inlet.ID, _ capability: Capability) async {}
}

private final class R5Cost: CostPort, @unchecked Sendable {
    func book(_ item: CostItem) {}
    func sum(_ inlet: Inlet.ID, _ period: Period) -> Cost { .zero }
}

private struct R5SignIn: SignInPort {
    func signIn(_ inlet: Inlet, input: [Field.ID: String]) async throws -> Grant { Grant(values: ["token": "t"]) }
    func renew(_ grant: Grant) async throws -> Grant { grant }
    func signOut(_ inlet: Inlet) async throws {}
}

private struct R5Probe: ProbePort {
    let accepting: R5Flag

    func probe(_ inlet: Inlet, _ grant: Grant) async throws -> ProbeResult {
        accepting.value ? ProbeResult(account: "a@x.test") : ProbeResult(account: "a@x.test", rejection: Hint(text: "hint.r5"))
    }
}

private struct R5Provider: Provider {
    let id = "double"
    let capabilities: Set<Capability> = [.mail]
    let form: [Field] = []
    let presets: [Preset] = []
    let signIn: any SignInPort = R5SignIn()
    let probe: any ProbePort

    init(accepting: R5Flag) { probe = R5Probe(accepting: accepting) }

    func adapter<P>(_ port: P.Type, for inlet: Inlet, _ grant: Grant, renewal: GrantRenewal) throws -> P {
        throw HubError.capabilityMissing(inlet.id, .mail)
    }
}

@MainActor
final class Repro5MailTests: XCTestCase {
    private func assembly(accepting: R5Flag, database: DatabaseQueue) throws -> MailSetup.Assembly {
        try MailSetup.assemble(
            person: Person(id: "p1", name: "P"), company: CompanySetup(), providers: [R5Provider(accepting: accepting)],
            database: database, keychain: R5Keychain(), cadence: R5Cadence(), cost: R5Cost(),
            cadences: MailSetup.defaultCadences, clock: { Date() })
    }

    private func rows(_ database: DatabaseQueue, _ inlet: Inlet.ID) throws -> Int {
        try database.read { db in
            try Int.fetchOne(db, sql: "SELECT (SELECT COUNT(*) FROM mail_message WHERE inlet = ?) + (SELECT COUNT(*) FROM mail_folder WHERE inlet = ?)",
                             arguments: [inlet, inlet]) ?? 0
        }
    }

    func testBug516RenewalResetsTheCadenceTheUserSet() async throws {
        let accepting = R5Flag(true)
        let result = try assembly(accepting: accepting, database: try HubDatabase.inMemory())
        let offer = try XCTUnwrap(result.hub.setup.offers.first)
        let inlet = try await result.hub.setup.add(offer)
        XCTAssertEqual(result.hub.rules.cadence(inlet.id, .mail), .every(.seconds(300)))
        result.hub.rules.setCadence(inlet.id, .mail, .every(.seconds(60)))
        accepting.value = false
        _ = try? await result.hub.setup.probe(inlet.id)
        XCTAssertTrue(result.hub.setup.inlets[0].state.canRenew)
        accepting.value = true
        let renewed = try await result.hub.setup.add(offer)
        XCTAssertEqual(renewed.id, inlet.id)
        XCTExpectFailure("BUG-5-16: PresetSetup.add sets the default cadence again after every add including a renewal, the cadence the user set is lost") {
            XCTAssertEqual(result.hub.rules.cadence(inlet.id, .mail), .every(.seconds(60)))
        }
    }

    func testBug517RemovedAccountLeavesItsMailInTheMirror() async throws {
        let database = try HubDatabase.inMemory()
        let result = try assembly(accepting: R5Flag(true), database: database)
        let inlet = try await result.hub.setup.add(try XCTUnwrap(result.hub.setup.offers.first))
        let mirror = try MailMirror(database)
        try mirror.replaceFolders(inlet.id, [MailFolder(id: "INBOX", name: "Inbox", role: .inbox)])
        try mirror.replaceMessages(inlet.id, folder: "INBOX", [MailMessageSummary(id: "m1", subject: "s", from: "a")], at: Date())
        try await result.hub.setup.remove(inlet.id)
        let left = try rows(database, inlet.id)
        XCTAssertEqual(left, 2)
        XCTExpectFailure("BUG-5-17: remove deletes keychain items and the inlet but never the mirrored folders, messages or outbox of the account") {
            XCTAssertEqual(left, 0)
        }
    }

    func testBug518RemovedSelectedAccountKeepsTheOldFoldersAndList() async {
        let engine = ModelFakeEngine()
        engine.accounts = [fakeAccount("a"), fakeAccount("b")]
        engine.folderList["a"] = [MailFolder(id: "INBOX-A", name: "Inbox", role: .inbox)]
        engine.folderList["b"] = [MailFolder(id: "INBOX-B", name: "Inbox", role: .inbox)]
        engine.pages[nil] = MailMessagePage(messages: [fakeMessage("m1")])
        let model = MailModel(engine: engine)
        await model.start()
        XCTAssertEqual(model.selectedInlet, "a")
        XCTAssertEqual(model.summaries.map(\.id), ["m1"])
        engine.accounts = [fakeAccount("b")]
        model.refreshAccounts()
        XCTAssertEqual(model.selectedInlet, "b")
        XCTAssertEqual(model.folders.map(\.id), ["INBOX-B"])
        XCTAssertTrue(model.summaries.isEmpty)
    }
}
