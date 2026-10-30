import Core
import Design
import Foundation
import GRDB
import Storage
import XCTest
@testable import Hub

private final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func with<R>(_ body: (inout Value) -> R) -> R {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}

private enum FakeError: Error, Equatable {
    case auth
    case down
    case refused
}

private struct FakeText: Error {
    let text: String
}

private struct StatusFailure: StatusErrorPort {
    let status: Int
}

private struct ShapeFailure: ShapeErrorPort {}

private actor Gate {
    private var open = false
    private var waiting: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if open { return }
        await withCheckedContinuation { waiting.append($0) }
    }

    func release() {
        open = true
        waiting.forEach { $0.resume() }
        waiting = []
    }
}

private actor Ticker {
    private var waiting: [CheckedContinuation<Void, Never>] = []
    private(set) var requested: [Duration] = []

    var waiters: Int { waiting.count }

    func sleep(_ duration: Duration) async {
        requested.append(duration)
        await withCheckedContinuation { waiting.append($0) }
    }

    func tick() {
        let current = waiting
        waiting = []
        current.forEach { $0.resume() }
    }
}

private actor Counter {
    private(set) var calls = 0
    private var gate: CheckedContinuation<Void, Never>?
    private var blocking = false

    func block() { blocking = true }

    func run() async {
        calls += 1
        guard blocking else { return }
        blocking = false
        await withCheckedContinuation { gate = $0 }
    }

    func release() {
        gate?.resume()
        gate = nil
    }
}

private protocol PingPort: Sendable {
    func ping() async throws -> Int
}

private final class FakePing: PingPort, @unchecked Sendable {
    private let state = Locked<(calls: Int, failure: (any Error)?, gate: Gate?)>((0, nil, nil))

    var calls: Int { state.with { $0.calls } }

    func setFailure(_ error: (any Error)?) { state.with { $0.failure = error } }

    func setGate(_ gate: Gate?) { state.with { $0.gate = gate } }

    func ping() async throws -> Int {
        let (gate, failure) = state.with { current -> (Gate?, (any Error)?) in
            current.calls += 1
            return (current.gate, current.failure)
        }
        if let gate { await gate.wait() }
        if let failure { throw failure }
        return 1
    }
}

private struct MeteredPing: PingPort {
    let wrapped: any PingPort
    let meter: CostMeter

    func ping() async throws -> Int {
        meter.record()
        return try await wrapped.ping()
    }
}

private struct FakeFiles: FilesPort {
    func projectFolders() async throws -> [FileFolder] { [FileFolder(id: "f1", name: "Project")] }
    func files(in folderID: String) async throws -> [FileEntry] { [] }
    func read(_ fileID: String) async throws -> Data { Data() }
    func put(name: String, mimeType: String, data: Data, into folderID: String) async throws -> FileEntry {
        FileEntry(id: name, name: name, mimeType: mimeType)
    }
}

private final class FakeChanges: ChangePort, @unchecked Sendable {
    private let state = Locked<(opened: Int, ended: Int, live: AsyncThrowingStream<Void, any Error>.Continuation?)>((0, 0, nil))

    var opened: Int { state.with { $0.opened } }
    var ended: Int { state.with { $0.ended } }

    func changes() -> AsyncThrowingStream<Void, any Error> {
        let (stream, continuation) = AsyncThrowingStream<Void, any Error>.makeStream()
        continuation.onTermination = { [state] _ in state.with { $0.ended += 1 } }
        state.with { $0.opened += 1; $0.live = continuation }
        return stream
    }

    func push() { state.with { _ = $0.live?.yield() } }

    func fail(_ error: any Error) { state.with { $0.live }?.finish(throwing: error) }
}

private final class FakeKeychain: KeychainPort, @unchecked Sendable {
    private let entries = Locked<[KeySlot: String]>([:])
    private let failing = Locked(false)
    private let unreadable = Locked(false)
    private let deletesLeft = Locked<Int?>(nil)

    var slots: Set<KeySlot> { entries.with { Set($0.keys) } }

    func setFailing(_ value: Bool) { failing.with { $0 = value } }
    func setUnreadable(_ value: Bool) { unreadable.with { $0 = value } }
    func failDeletes(after count: Int?) { deletesLeft.with { $0 = count } }

    func put(_ value: String, at slot: KeySlot) throws {
        if failing.with({ $0 }) { throw KeychainFailure.status(-25_300) }
        entries.with { $0[slot] = value }
    }

    func get(_ slot: KeySlot) throws -> String? {
        if unreadable.with({ $0 }) { throw KeychainFailure.status(-25_308) }
        return entries.with { $0[slot] }
    }

    func delete(_ slot: KeySlot) throws {
        if let left = deletesLeft.with({ $0 }) {
            if left == 0 {
                entries.with { $0[slot] = nil }
                throw KeychainFailure.status(-25_244)
            }
            deletesLeft.with { $0 = left - 1 }
        }
        entries.with { $0[slot] = nil }
    }
}

private final class HandCadence: CadencePort, @unchecked Sendable {
    private let runner = Locked<SyncPort?>(nil)
    private let planned = Locked<[String: Cadence]>([:])
    private let fired = Locked(0)
    private let continuation: AsyncStream<SyncReport>.Continuation
    let reports: AsyncStream<SyncReport>

    init() {
        (reports, continuation) = AsyncStream<SyncReport>.makeStream()
    }

    var triggers: Int { fired.with { $0 } }

    func planned(_ inlet: Inlet.ID, _ capability: Capability) -> Cadence? {
        planned.with { $0[inlet + "|" + capability.rawValue] }
    }

    func attach(_ runner: @escaping SyncPort) { self.runner.with { $0 = runner } }

    func plan(_ inlet: Inlet.ID, _ capability: Capability, _ cadence: Cadence) {
        planned.with { $0[inlet + "|" + capability.rawValue] = cadence }
    }

    func trigger(_ inlet: Inlet.ID, _ capability: Capability) async {
        fired.with { $0 += 1 }
        guard let run = runner.with({ $0 }) else { return }
        continuation.yield(await run(inlet, capability))
    }
}

private final class FakeCost: CostPort, @unchecked Sendable {
    private let items = Locked<[CostItem]>([])

    var all: [CostItem] { items.with { $0 } }

    var calls: Int { items.with { $0.reduce(0) { $0 + $1.cost.calls } } }

    func book(_ item: CostItem) { items.with { $0.append(item) } }
}

private struct FakeSignIn: SignInPort {
    func signIn(_ inlet: Inlet, input: [Field.ID: String]) async throws -> Grant {
        Grant(values: ["token": input["address"] ?? inlet.id])
    }

    func renew(_ grant: Grant) async throws -> Grant { grant }

    func signOut(_ inlet: Inlet) async throws {}
}

private struct GivenSignIn: SignInPort {
    let grant: Grant

    func signIn(_ inlet: Inlet, input: [Field.ID: String]) async throws -> Grant { grant }

    func renew(_ grant: Grant) async throws -> Grant { grant }

    func signOut(_ inlet: Inlet) async throws {}
}

private struct StuckSignIn: SignInPort {
    func signIn(_ inlet: Inlet, input: [Field.ID: String]) async throws -> Grant {
        try await Task.sleep(for: .seconds(3600))
        return Grant(values: [:])
    }

    func renew(_ grant: Grant) async throws -> Grant { grant }

    func signOut(_ inlet: Inlet) async throws {}
}

private struct FakeProbe: ProbePort {
    let accepting: Locked<Bool>
    let stalling: Locked<Bool>

    func probe(_ inlet: Inlet, _ grant: Grant) async throws -> ProbeResult {
        if stalling.with({ $0 }) { try await Task.sleep(for: .seconds(3600)) }
        let account = grant.values["token"] ?? inlet.id
        if accepting.with({ $0 }) { return ProbeResult(account: account) }
        return ProbeResult(account: account, rejection: Hint(text: "hint.fake.rejected"))
    }
}

private final class FakeProvider: ProviderPort, @unchecked Sendable {
    let id: String
    let capabilities: Set<Capability>
    let form: [Field]
    let presets: [Preset]
    let ping = FakePing()
    let changes = FakeChanges()
    let renewals = Locked<[GrantRenewal]>([])
    let signIn: any SignInPort
    let probe: any ProbePort
    private let accepting = Locked(true)
    private let stalling = Locked(false)

    init(id: String = "fake", capabilities: Set<Capability>, signIn: (any SignInPort)? = nil, form: [Field] = [], presets: [Preset] = []) {
        self.id = id
        self.capabilities = capabilities
        self.signIn = signIn ?? FakeSignIn()
        self.form = form
        self.presets = presets
        probe = FakeProbe(accepting: accepting, stalling: stalling)
    }

    func setAccepting(_ value: Bool) { accepting.with { $0 = value } }

    func setStalling(_ value: Bool) { stalling.with { $0 = value } }

    func classify(_ error: any Error) -> Classification {
        if let text = error as? FakeText {
            return Classification(kind: .transient, original: Original(provider: "fake", text: text.text))
        }
        switch error as? FakeError {
        case .auth: return Classification(kind: .signIn, original: Original(provider: "fake", code: "auth"))
        case .down: return Classification(kind: .transient, original: Original(provider: "fake", code: "down"))
        case .refused: return Classification(kind: .rejected, original: Original(provider: "fake", code: "refused"))
        case nil: return Classification.generic(error)
        }
    }

    func adapter<P>(_ port: P.Type, for inlet: Inlet, _ grant: Grant, renewal: GrantRenewal) throws -> P {
        renewals.with { $0.append(renewal) }
        let made: Any
        switch ObjectIdentifier(port) {
        case ObjectIdentifier((any PingPort).self): made = ping as any PingPort
        case ObjectIdentifier((any FilesPort).self): made = FakeFiles() as any FilesPort
        case ObjectIdentifier((any ChangePort).self): made = changes as any ChangePort
        default: throw HubFailure.capabilityMissing(inlet.id, inlet.capabilities.first ?? .mail)
        }
        guard let typed = made as? P else { throw HubFailure.capabilityMissing(inlet.id, .mail) }
        return typed
    }
}

private func registry() -> PortRegistry {
    var registry = PortRegistry()
    registry.register(
        (any PingPort).self,
        capability: .mail,
        wrap: { MeteredPing(wrapped: $0, meter: $1) },
        sync: { port, inlet in
            let value = try await port.ping()
            return SyncOutcome(deliveries: [.mailboxes: [Mailbox(id: inlet + "/" + String(value), inlet: inlet, name: "Inbox", role: "inbox")]])
        }
    )
    return registry.withFiles()
}

@MainActor
private struct Rig {
    static let offer = Offer(
        id: "fake.mail", provider: "fake", title: "Mail", capabilities: [.mail], owner: .person("p1"),
        way: .form([Field(id: "address", title: "address", holdsAccount: true)]))

    static let filesOffer = Offer(
        id: "fake.files", provider: "fake", title: "Files", capabilities: [.mail, .files], owner: .person("p1"),
        way: .form([Field(id: "address", title: "address", holdsAccount: true)]))

    let connections: Connections
    let provider: FakeProvider
    let keychain: FakeKeychain
    let cadence: HandCadence
    let cost: FakeCost
    let database: SQLiteStore

    static func make(
        capabilities: Set<Capability> = [.mail], offers: [Offer] = [Rig.offer],
        database: SQLiteStore? = nil, provider: FakeProvider? = nil, keychain: FakeKeychain? = nil,
        cadences: [Capability: Duration] = [:], deadlines: Deadlines = .standard, reportLimit: Int = 100,
        providers: [any ProviderPort]? = nil
    ) throws -> Rig {
        let provider = provider ?? FakeProvider(capabilities: capabilities)
        let keychain = keychain ?? FakeKeychain()
        let cadence = HandCadence()
        let cost = FakeCost()
        let database = try database ?? SQLiteStore.inMemory()
        let configuration = Configuration(
            person: Person(id: "p1", name: "P"), company: CompanySetup(offers: offers),
            providers: providers ?? [provider], keychain: keychain, cadence: cadence, cost: cost, catalog: registry(),
            deadlines: deadlines, reportLimit: reportLimit, cadences: cadences)
        return Rig(connections: try Connections.make(configuration, database: database), provider: provider,
                   keychain: keychain, cadence: cadence, cost: cost, database: database)
    }

    func connect(_ address: String, offer: Offer = Rig.offer) async throws -> Inlet {
        try await connections.setup.add(offer, input: .fields(["address": address]))
    }
}

private struct StubCheck: ConnectionCheckPort {
    let integration: String
    let body: @Sendable (KeyValues) async throws -> String?

    func check(_ values: KeyValues) async throws -> String? { try await body(values) }
}

@MainActor
private func until(_ condition: @MainActor () -> Bool) async -> Bool {
    for _ in 0..<400 {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return condition()
}

final class HubTests: XCTestCase {
    @MainActor
    func testStartsEmptyAndNothingThrows() throws {
        let rig = try Rig.make()
        XCTAssertEqual(rig.connections.setup.inlets, [])
        let stock = rig.connections.access.stock(.mailboxes, as: Mailbox.self)
        XCTAssertEqual(stock.items, [])
        XCTAssertEqual(stock.phase, .empty)
        XCTAssertEqual(rig.connections.access.inlets(for: .mail), [])
        XCTAssertTrue(rig.keychain.slots.isEmpty)
    }

    @MainActor
    func testRejectedProbeLeavesNothingBehind() async throws {
        let rig = try Rig.make()
        rig.provider.setAccepting(false)
        do {
            _ = try await rig.connect("a@x")
            XCTFail("add must throw")
        } catch SetupFailure.probeFailed {
        }
        XCTAssertEqual(rig.connections.setup.inlets, [])
        XCTAssertTrue(rig.keychain.slots.isEmpty)
    }

    @MainActor
    func testAcceptedProbeConnectsAndPortsFollowCapabilities() async throws {
        let rig = try Rig.make()
        let inlet = try await rig.connect("a@x")
        guard case .connected = inlet.state else { return XCTFail("state \(inlet.state)") }
        XCTAssertEqual(rig.connections.setup.inlets.map(\.id), [inlet.id])
        let ping = try rig.connections.access.port((any PingPort).self, for: inlet.id)
        let value = try await ping.ping()
        XCTAssertEqual(value, 1)
        XCTAssertEqual(rig.cost.calls, 1)
        XCTAssertThrowsError(try rig.connections.access.port((any FilesPort).self, for: inlet.id)) {
            XCTAssertEqual($0 as? HubFailure, .capabilityMissing(inlet.id, .files))
        }
        XCTAssertThrowsError(try rig.connections.access.port((any ChangePort).self, for: inlet.id)) {
            XCTAssertEqual($0 as? HubFailure, .provider(Hint(text: "hint.port.unknown", detail: String(describing: (any ChangePort).self))))
        }
        XCTAssertThrowsError(try rig.connections.access.port((any PingPort).self, for: "nobody")) {
            XCTAssertEqual($0 as? HubFailure, .notConnected("nobody"))
        }
    }

    @MainActor
    func testAnyNumberOfMailAccountsCanBeConnected() async throws {
        let rig = try Rig.make()
        for address in ["a@x", "b@x", "c@x", "d@x", "e@x"] { _ = try await rig.connect(address) }
        XCTAssertEqual(rig.connections.setup.inlets.count, 5)
    }

    @MainActor
    func testTwoOffersOfOneProviderCarryTheirOwnCapabilitiesAndRefuseTheSameAddress() async throws {
        let mailOnly = Offer(
            id: "fake.gmail", provider: "fake", title: "Gmail", capabilities: [.mail], owner: .person("p1"),
            way: .form([Field(id: "address", title: "address", holdsAccount: true)]))
        let full = Offer(
            id: "fake.google", provider: "fake", title: "Google", capabilities: [.mail, .calendar, .contacts, .files],
            owner: .person("p1"), way: .form([Field(id: "address", title: "address", holdsAccount: true)]))
        let provider = FakeProvider(capabilities: [.mail, .calendar, .contacts, .files])
        let rig = try Rig.make(offers: [mailOnly, full], provider: provider)
        let small = try await rig.connect("a@x.test", offer: mailOnly)
        let large = try await rig.connect("b@x.test", offer: full)
        XCTAssertEqual(small.capabilities, [.mail])
        XCTAssertEqual(large.capabilities, [.mail, .calendar, .contacts, .files])
        do {
            _ = try await rig.connect("a@x.test", offer: full)
            XCTFail("add must throw")
        } catch {
            XCTAssertEqual(error as? SetupFailure, .duplicate)
        }
        XCTAssertEqual(rig.connections.setup.inlets.count, 2)
    }

    @MainActor
    func testTheSameAddressIsRefusedAcrossProvidersAndCases() async throws {
        let first = FakeProvider(capabilities: [.mail])
        let other = FakeProvider(id: "other", capabilities: [.mail])
        let otherOffer = Offer(
            id: "other.mail", provider: "other", title: "Other", capabilities: [.mail], owner: .person("p1"),
            way: .form([Field(id: "address", title: "address", holdsAccount: true)]))
        let rig = try Rig.make(offers: [Rig.offer, otherOffer], provider: first, providers: [first, other])
        _ = try await rig.connect("Anna@X.test")
        for (address, offer) in [("anna@x.test", Rig.offer), ("ANNA@x.test", otherOffer), (" anna@x.test ", otherOffer)] {
            do {
                _ = try await rig.connect(address, offer: offer)
                XCTFail("add must throw")
            } catch {
                XCTAssertEqual(error as? SetupFailure, .duplicate)
            }
        }
        XCTAssertEqual(rig.connections.setup.inlets.count, 1)
        _ = try await rig.connect("berta@x.test", offer: otherOffer)
        XCTAssertEqual(rig.connections.setup.inlets.count, 2)
    }

    @MainActor
    func testAFailedAccountIsNeverRenewedThroughAnotherProvider() async throws {
        let first = FakeProvider(capabilities: [.mail])
        let other = FakeProvider(id: "other", capabilities: [.mail])
        let otherOffer = Offer(
            id: "other.mail", provider: "other", title: "Other", capabilities: [.mail], owner: .person("p1"),
            way: .form([Field(id: "address", title: "address", holdsAccount: true)]))
        let rig = try Rig.make(offers: [Rig.offer, otherOffer], provider: first, providers: [first, other])
        let inlet = try await rig.connect("a@x")
        first.setAccepting(false)
        _ = try? await rig.connections.setup.probe(inlet.id)
        XCTAssertTrue(rig.connections.setup.inlets[0].state.canRenew)
        do {
            _ = try await rig.connect("a@x", offer: otherOffer)
            XCTFail("add must throw")
        } catch {
            XCTAssertEqual(error as? SetupFailure, .duplicate)
        }
        XCTAssertEqual(rig.connections.setup.inlets.map(\.provider), ["fake"])
    }

    @MainActor
    func testRenewalRefusesAnotherAddressAndKeepsTheFailedInlet() async throws {
        let rig = try Rig.make()
        let first = try await rig.connect("a@x")
        rig.provider.setAccepting(false)
        _ = try? await rig.connections.setup.probe(first.id)
        rig.provider.setAccepting(true)
        let renewal = try XCTUnwrap(rig.connections.setup.renewal(of: first.id))
        XCTAssertEqual(renewal.values[Input.expectedAccountKey], "a@x")
        var wrong = renewal.values
        wrong["address"] = "b@x"
        do {
            _ = try await rig.connections.setup.add(renewal.offer, input: .fields(wrong))
            XCTFail("add must throw")
        } catch {
            XCTAssertEqual(error, .probeFailed(Hint(text: HintEngine.accountMismatchText, detail: "a@x")))
        }
        XCTAssertEqual(rig.connections.setup.inlets.map(\.id), [first.id])
        XCTAssertTrue(rig.connections.setup.inlets[0].state.canRenew)
        var right = renewal.values
        right["address"] = "A@X"
        let renewed = try await rig.connections.setup.add(renewal.offer, input: .fields(right))
        XCTAssertEqual(renewed.id, first.id)
    }

    @MainActor
    func testRenewalKeepsTheCadenceTheUserChose() async throws {
        let rig = try Rig.make(cadences: [.mail: .seconds(300)])
        let first = try await rig.connect("a@x")
        rig.connections.rules.setCadence(first.id, .mail, .manual)
        rig.provider.setAccepting(false)
        _ = try? await rig.connections.setup.probe(first.id)
        rig.provider.setAccepting(true)
        _ = try await rig.connect("a@x")
        XCTAssertEqual(rig.connections.rules.cadence(first.id, .mail), .manual)
    }

    @MainActor
    func testCadenceRunsOnePairOnceAndCountsTheCall() async throws {
        let rig = try Rig.make()
        let inlet = try await rig.connect("a@x")
        rig.connections.rules.setCadence(inlet.id, .mail, .every(.seconds(300)))
        XCTAssertEqual(rig.cadence.planned(inlet.id, .mail), .every(.seconds(300)))
        XCTAssertEqual(rig.connections.rules.cadence(inlet.id, .mail), .every(.seconds(300)))
        let gate = Gate()
        rig.provider.ping.setGate(gate)
        let first = Task { @MainActor in await rig.cadence.trigger(inlet.id, .mail) }
        let started = await until { rig.provider.ping.calls == 1 }
        XCTAssertTrue(started)
        XCTAssertEqual(rig.connections.rules.queue.map(\.inlet), [inlet.id])
        await rig.cadence.trigger(inlet.id, .mail)
        await gate.release()
        await first.value
        XCTAssertEqual(rig.provider.ping.calls, 1)
        XCTAssertEqual(rig.cost.calls, 1)
        XCTAssertEqual(rig.connections.rules.queue, [])
        XCTAssertNotNil(rig.connections.rules.lastSync(inlet.id, .mail))
        let stock = rig.connections.access.stock(.mailboxes, as: Mailbox.self)
        XCTAssertEqual(stock.items.map(\.name), ["Inbox"])
        guard case .connected = rig.connections.setup.inlets[0].state else { return XCTFail("state") }
    }

    @MainActor
    func testRemoveKeepsTheKeysOfTheOtherInlet() async throws {
        let rig = try Rig.make()
        let a = try await rig.connect("a@x")
        let b = try await rig.connect("b@x")
        XCTAssertEqual(Set(rig.keychain.slots.map(\.inlet)), [a.id, b.id])
        let settings = try SettingsState(settings: SettingStore(database: rig.database))
        settings.setDisplay(.domain, for: a.id)
        settings.setDisplay(.localPart, for: b.id)
        try await rig.connections.setup.remove(a.id)
        let after = try SettingsState(settings: SettingStore(database: rig.database))
        XCTAssertEqual(after.display(a.id), .ownName)
        XCTAssertEqual(after.display(b.id), .localPart)
        XCTAssertEqual(rig.keychain.slots.map(\.inlet), [b.id])
        XCTAssertEqual(rig.connections.setup.inlets.map(\.id), [b.id])
        _ = try rig.connections.access.port((any PingPort).self, for: b.id)
    }

    @MainActor
    func testRemoveIsAllOrNothing() async throws {
        let grant = Grant(values: ["a": "1", "b": "2"])
        let rig = try Rig.make(provider: FakeProvider(capabilities: [.mail], signIn: GivenSignIn(grant: grant)))
        let inlet = try await rig.connect("a@x")
        XCTAssertEqual(rig.keychain.slots.count, 2)
        rig.keychain.failDeletes(after: 1)
        var failed = false
        do { try await rig.connections.setup.remove(inlet.id) } catch { failed = true }
        XCTAssertTrue(failed)
        XCTAssertEqual(rig.keychain.slots.count, 2)
        XCTAssertEqual(try rig.keychain.get(KeySlot(inlet: inlet.id, name: "a")), "1")
        XCTAssertEqual(try rig.keychain.get(KeySlot(inlet: inlet.id, name: "b")), "2")
        XCTAssertEqual(rig.connections.setup.inlets.map(\.id), [inlet.id])
        XCTAssertNotEqual(rig.cadence.planned(inlet.id, .mail), .off)
        rig.keychain.failDeletes(after: nil)
        try await rig.connections.setup.remove(inlet.id)
        XCTAssertEqual(rig.keychain.slots.count, 0)
        XCTAssertEqual(rig.connections.setup.inlets, [])
    }

    @MainActor
    func testRemoveWorksWhenTheKeysCannotBeRead() async throws {
        let rig = try Rig.make()
        let inlet = try await rig.connect("a@x")
        rig.keychain.setUnreadable(true)
        try await rig.connections.setup.remove(inlet.id)
        XCTAssertEqual(rig.connections.setup.inlets, [])
        rig.keychain.setUnreadable(false)
        XCTAssertEqual(rig.keychain.slots.count, 0)
    }

    @MainActor
    func testRemoveTurnsTheCadenceOffAndForgetsTheInletSettings() async throws {
        let rig = try Rig.make()
        let a = try await rig.connect("a@x")
        rig.connections.rules.setCadence(a.id, .mail, .every(.seconds(60)))
        XCTAssertNotEqual(rig.cadence.planned(a.id, .mail), .off)
        let settings = SettingStore(database: rig.database)
        let sibling = SettingsKey.mailboxDisplay(a.id + "x")
        try settings.store(MailboxDisplay.domain.rawValue, forKey: SettingsKey.mailboxDisplay(a.id))
        try settings.store(MailboxDisplay.domain.rawValue, forKey: sibling)
        try await rig.connections.setup.remove(a.id)
        XCTAssertEqual(rig.cadence.planned(a.id, .mail), .off)
        XCTAssertEqual(rig.connections.rules.cadence(a.id, .mail), .manual)
        let remaining = try rig.database.read { db in try String.fetchAll(db, sql: "SELECT key FROM setting WHERE instr(key, ?) > 0", arguments: [a.id]) }
        XCTAssertEqual(remaining, [sibling])
    }

    @MainActor
    func testCancelDuringTheProbe() async throws {
        let stuck = try Rig.make()
        stuck.provider.setStalling(true)
        let addTask = Task { @MainActor () -> SetupFailure? in
            do {
                _ = try await stuck.connect("a@x")
                return nil
            } catch {
                return error as? SetupFailure
            }
        }
        try await Task.sleep(for: .milliseconds(300))
        addTask.cancel()
        let addError = await addTask.value
        XCTAssertEqual(addError, .cancelled)
        let rig = try Rig.make()
        let inlet = try await rig.connect("a@x")
        rig.provider.setStalling(true)
        let probeTask = Task { @MainActor in _ = try? await rig.connections.setup.probe(inlet.id) }
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(rig.connections.setup.inlets.first?.state, .connecting)
        probeTask.cancel()
        await probeTask.value
        XCTAssertEqual(rig.connections.setup.inlets.first?.state.isConnected, true)
    }

    @MainActor
    func testInletsOfAMissingProviderSurviveARestart() async throws {
        let database = try SQLiteStore.inMemory()
        let keychain = FakeKeychain()
        let first = try Rig.make(database: database, keychain: keychain)
        let connected = try await first.connect("a@x")
        let failedOne = try await first.connect("b@x")
        first.provider.setAccepting(false)
        _ = try? await first.connections.setup.probe(failedOne.id)
        let restarted = try Rig.make(offers: [], database: database, keychain: keychain, providers: [])
        XCTAssertEqual(restarted.connections.setup.inlets.count, 2)
        XCTAssertTrue(restarted.connections.setup.inlets.first { $0.id == failedOne.id }?.state.canRenew == true)
        XCTAssertThrowsError(try restarted.connections.access.port((any PingPort).self, for: connected.id))
        XCTAssertEqual(restarted.connections.access.configured(for: .mail).count, 2)
        XCTAssertEqual(restarted.connections.access.inlets(for: .mail).count, 1)
        let again = try Rig.make(database: database, keychain: keychain)
        guard case .connected(let probed)? = again.connections.setup.inlets.first(where: { $0.id == connected.id })?.state else {
            return XCTFail("connected inlet must stay connected across a restart")
        }
        XCTAssertNotEqual(probed, .distantPast)
        try await Task.sleep(for: .milliseconds(5))
        _ = try await again.connections.setup.probe(connected.id)
        guard case .connected(let reprobed)? = again.connections.setup.inlets.first(where: { $0.id == connected.id })?.state else {
            return XCTFail("probe keeps the inlet connected")
        }
        XCTAssertGreaterThan(reprobed, probed)
        let third = try Rig.make(database: database, keychain: keychain)
        guard case .connected(let stored)? = third.connections.setup.inlets.first(where: { $0.id == connected.id })?.state else {
            return XCTFail("reprobed inlet must stay connected")
        }
        XCTAssertEqual(stored.timeIntervalSince1970, reprobed.timeIntervalSince1970, accuracy: 0.001)
    }

    @MainActor
    func testIntegrationReadingLeadsWithTheFirstInletOfTheCombinedState() async throws {
        let info = IntegrationInfo(id: "fake", access: .password, companyOwned: false, fields: [], areas: [], extras: [],
                                   listsAccounts: true, providers: ["fake"], logo: nil)
        let rig = try Rig.make()
        let first = try await rig.connect("a@x")
        try await Task.sleep(for: .milliseconds(5))
        _ = try await rig.connect("b@x")
        guard case .connected(let probed) = first.state else { return XCTFail("state \(first.state)") }
        let reading = IntegrationReadEngine.read(info, setup: rig.connections.setup, rules: rig.connections.rules)
        XCTAssertEqual(reading.note, .checked(probed))
    }

    @MainActor
    func testCorruptRowsDoNotStopTheHub() async throws {
        let database = try SQLiteStore.inMemory()
        let keychain = FakeKeychain()
        let first = try Rig.make(database: database, keychain: keychain)
        let good = try await first.connect("a@x")
        try database.write { db in
            try db.execute(sql: "INSERT INTO inlet (id, json) VALUES ('broken', ?)", arguments: [Data("garbage".utf8)])
            try db.execute(sql: "INSERT INTO key_slot (inlet, name) VALUES ('broken', 'token')")
            try db.execute(sql: "INSERT INTO setting (key, value) VALUES ('cadence|x|mail', ?)", arguments: [Data("garbage".utf8)])
            try db.execute(sql: "INSERT INTO setting (key, value) VALUES ('lastsync|x|mail', ?)", arguments: [Data("x".utf8)])
            try db.execute(sql: "INSERT INTO setting (key, value) VALUES ('other', ?)", arguments: [Data("x".utf8)])
            try db.execute(sql: "INSERT INTO inlet_report (inlet, at, json) VALUES ('x', 1, ?)", arguments: [Data("garbage".utf8)])
        }
        let again = try Rig.make(database: database, provider: first.provider, keychain: keychain)
        XCTAssertEqual(again.connections.setup.inlets.map(\.id), [good.id])
        XCTAssertEqual(try InletStore(database: database).slots(of: "broken"), ["token"])
        XCTAssertEqual(again.connections.rules.cadence("x", .mail), .manual)
        XCTAssertEqual(again.connections.setup.report(for: "x"), [])
    }

    @MainActor
    func testWorkingAndConnectingAreNeverStored() async throws {
        let database = try SQLiteStore.inMemory()
        let keychain = FakeKeychain()
        let rig = try Rig.make(database: database, keychain: keychain)
        let inlet = try await rig.connect("a@x")
        let gate = Gate()
        rig.provider.ping.setGate(gate)
        let running = Task { @MainActor in await rig.cadence.trigger(inlet.id, .mail) }
        let started = await until { rig.provider.ping.calls == 1 }
        XCTAssertTrue(started)
        XCTAssertEqual(rig.connections.setup.inlets[0].state, .working)
        rig.connections.rules.setCadence(inlet.id, .mail, .manual)
        let stored = try InletStore(database: database).load()
        XCTAssertNotEqual(stored[0].state, .working)
        XCTAssertTrue(stored[0].state.isConnected)
        await gate.release()
        await running.value
        try database.write { db in
            var legacy = inlet
            legacy.state = .working
            try db.execute(sql: "UPDATE inlet SET json = ? WHERE id = ?", arguments: [try JSONEncoder().encode(legacy), inlet.id])
        }
        let old = try Rig.make(database: database, provider: rig.provider, keychain: keychain)
        XCTAssertNotEqual(old.connections.setup.inlets[0].state, .working)
        XCTAssertTrue(old.connections.setup.inlets[0].state.isConnected)
        let reading = IntegrationReadEngine.read(
            IntegrationInfo(id: "fake", access: .password, companyOwned: false, fields: [], areas: [], extras: [],
                            listsAccounts: true, providers: ["fake"], logo: nil),
            setup: old.connections.setup, rules: old.connections.rules)
        XCTAssertEqual(reading.note, .unchecked)
    }

    @MainActor
    func testFailedInletIsRenewedInPlace() async throws {
        let rig = try Rig.make()
        let first = try await rig.connect("a@x")
        rig.provider.setAccepting(false)
        do {
            _ = try await rig.connections.setup.probe(first.id)
            XCTFail("probe must throw")
        } catch SetupFailure.probeFailed {
        }
        XCTAssertTrue(rig.connections.setup.inlets[0].state.canRenew)
        let renewal = try XCTUnwrap(rig.connections.setup.renewal(of: first.id))
        XCTAssertEqual(renewal.offer, Rig.offer)
        XCTAssertEqual(renewal.values, ["address": "a@x", Input.expectedAccountKey: "a@x"])
        rig.provider.setAccepting(true)
        let renewed = try await rig.connect("a@x")
        XCTAssertEqual(renewed.id, first.id)
        XCTAssertEqual(rig.connections.setup.inlets.map(\.id), [first.id])
        guard case .connected(let probed) = rig.connections.setup.inlets[0].state else { return XCTFail("state") }
        XCTAssertGreaterThan(probed, .distantPast)
        XCTAssertEqual(rig.keychain.slots.map(\.inlet), [first.id])
        XCTAssertNil(rig.connections.setup.renewal(of: first.id))
        _ = try rig.connections.access.port((any PingPort).self, for: first.id)
    }

    @MainActor
    func testConnectedInletStillRefusesTheSameAccount() async throws {
        let rig = try Rig.make()
        _ = try await rig.connect("a@x")
        do {
            _ = try await rig.connect("a@x")
            XCTFail("add must throw")
        } catch {
            XCTAssertEqual(error as? SetupFailure, .duplicate)
        }
        XCTAssertEqual(rig.connections.setup.inlets.count, 1)
    }

    @MainActor
    func testUnknownProviderAndKeychainWriteFailureAreReported() async throws {
        let rig = try Rig.make()
        let stranger = Offer(id: "x", provider: "none", title: "X", capabilities: [.mail], owner: .person("p1"), way: .signIn)
        do {
            _ = try await rig.connections.setup.add(stranger, input: .none)
            XCTFail("add must throw")
        } catch {
            XCTAssertEqual(error, .probeFailed(Hint(text: "hint.provider.unknown", detail: "none")))
        }
        rig.keychain.setFailing(true)
        do {
            _ = try await rig.connect("a@x")
            XCTFail("add must throw")
        } catch {
            XCTAssertEqual(error as? SetupFailure, .keychain(-25_300))
        }
        XCTAssertEqual(rig.connections.setup.inlets, [])
        XCTAssertTrue(rig.keychain.slots.isEmpty)
    }

    @MainActor
    func testSyncFailuresMoveTheInletState() async throws {
        let rig = try Rig.make()
        let inlet = try await rig.connect("a@x")
        rig.provider.ping.setFailure(FakeError.down)
        await rig.cadence.trigger(inlet.id, .mail)
        XCTAssertTrue(rig.connections.setup.inlets[0].state.isConnected)
        rig.provider.ping.setFailure(nil)
        await rig.cadence.trigger(inlet.id, .mail)
        rig.provider.ping.setFailure(FakeError.auth)
        await rig.cadence.trigger(inlet.id, .mail)
        guard case .failed(let hint) = rig.connections.setup.inlets[0].state else { return XCTFail("state") }
        XCTAssertEqual(hint.text, Hint.signInExpiredText)
        XCTAssertEqual(hint.original?.code, "auth")
        XCTAssertEqual(hint.fixIn, .inlet(inlet.id))
        XCTAssertEqual(rig.connections.access.inlets(for: .mail), [])
        XCTAssertEqual(rig.connections.access.configured(for: .mail).map(\.id), [inlet.id])
    }

    @MainActor
    func testReportKeepsTheOriginalAcrossARestart() async throws {
        let database = try SQLiteStore.inMemory()
        let keychain = FakeKeychain()
        let rig = try Rig.make(database: database, keychain: keychain)
        let inlet = try await rig.connect("a@x")
        rig.provider.ping.setFailure(FakeText(text: "try later"))
        await rig.cadence.trigger(inlet.id, .mail)
        let again = try Rig.make(database: database, provider: rig.provider, keychain: keychain)
        let entry = try XCTUnwrap(again.connections.setup.report(for: inlet.id).first)
        XCTAssertEqual(entry.event, .sync)
        XCTAssertEqual(entry.capability, .mail)
        XCTAssertFalse(entry.ok)
        XCTAssertEqual(entry.kind, .transient)
        XCTAssertEqual(entry.original?.text, "try later")
        XCTAssertTrue(again.connections.setup.inlets[0].state.isConnected)
    }

    @MainActor
    func testReportIsLimitedPerInletAndRepeatedSuccessIsNotLogged() async throws {
        let rig = try Rig.make(reportLimit: 3)
        let inlet = try await rig.connect("a@x")
        for number in 1...5 {
            rig.provider.ping.setFailure(FakeText(text: "attempt " + String(number)))
            await rig.cadence.trigger(inlet.id, .mail)
        }
        let entries = rig.connections.setup.report(for: inlet.id)
        XCTAssertEqual(entries.map { $0.original?.text }, ["attempt 5", "attempt 4", "attempt 3"])
        let calm = try Rig.make()
        let other = try await calm.connect("a@x")
        for _ in 1...3 { await calm.cadence.trigger(other.id, .mail) }
        XCTAssertEqual(calm.connections.setup.report(for: other.id).filter { $0.event == .sync }.count, 1)
        XCTAssertEqual(calm.connections.setup.report(for: other.id).filter { $0.event == .probe }.count, 1)
    }

    @MainActor
    func testSignInDeadlineEndsWithTheSignInTimeout() async throws {
        let provider = FakeProvider(capabilities: [.mail], signIn: StuckSignIn())
        let rig = try Rig.make(provider: provider, deadlines: Deadlines(signIn: .milliseconds(200), probe: .seconds(5)))
        do {
            _ = try await rig.connections.setup.add(Rig.offer, input: .none)
            XCTFail("add must throw")
        } catch {
            XCTAssertEqual(error, .probeFailed(Hint(text: "hint.signin.timeout")))
        }
        XCTAssertEqual(rig.connections.setup.inlets, [])
    }

    @MainActor
    func testProbeDeadlineKeepsAConnectedInletConnected() async throws {
        let rig = try Rig.make(deadlines: Deadlines(signIn: .seconds(5), probe: .milliseconds(150)))
        let inlet = try await rig.connect("a@x")
        rig.provider.setStalling(true)
        do {
            _ = try await rig.connections.setup.probe(inlet.id)
            XCTFail("probe must throw")
        } catch {
            guard case .probeFailed(let hint) = error else { return XCTFail("error \(error)") }
            XCTAssertEqual(hint.text, "hint.probe.timeout")
            XCTAssertEqual(hint.kind, .transient)
        }
        XCTAssertTrue(rig.connections.setup.inlets[0].state.isConnected)
    }

    @MainActor
    func testSyncFillsTheStockAndRemoveEmptiesIt() async throws {
        let rig = try Rig.make(capabilities: [.mail, .files], offers: [Rig.filesOffer])
        let inlet = try await rig.connect("a@x", offer: Rig.filesOffer)
        let stock = rig.connections.access.stock(.files, as: ProjectFolder.self)
        XCTAssertEqual(stock.phase, .empty)
        await stock.refresh()
        XCTAssertEqual(stock.items.map(\.folder.name), ["Project"])
        XCTAssertEqual(stock.items.map(\.id), [inlet.id + "/f1"])
        guard case .current = stock.phase else { return XCTFail("phase \(stock.phase)") }
        let late = rig.connections.access.stock(.files, as: ProjectFolder.self)
        XCTAssertTrue(late === stock)
        try await rig.connections.setup.remove(inlet.id)
        XCTAssertEqual(stock.items, [])
        XCTAssertEqual(stock.phase, .empty)
        XCTAssertEqual(rig.cost.calls, 1)
    }

    @MainActor
    func testFailedSyncDisturbsTheStockAndMarksTheInlet() async throws {
        let rig = try Rig.make()
        let inlet = try await rig.connect("a@x")
        let stock = rig.connections.access.stock(.mailboxes, as: Mailbox.self)
        rig.provider.ping.setFailure(FakeError.refused)
        var events: [InletEvent] = []
        let stream = rig.connections.access.events
        let collector = Task { @MainActor in for await event in stream { events.append(event) } }
        await rig.cadence.trigger(inlet.id, .mail)
        guard case .disturbed(let hint) = stock.phase else { return XCTFail("phase \(stock.phase)") }
        XCTAssertEqual(hint.text, "hint.provider.failed")
        guard case .failed(let state) = rig.connections.setup.inlets[0].state else { return XCTFail("state") }
        XCTAssertEqual(state, hint)
        let seen = await until { events.contains(.syncFailed(.mail, inlet.id, hint)) }
        XCTAssertTrue(seen)
        collector.cancel()
        await stock.refresh()
        XCTAssertEqual(stock.items, [])
    }

    @MainActor
    func testEventsAnnounceChangesSyncsAndRemoval() async throws {
        let rig = try Rig.make()
        var events: [InletEvent] = []
        let stream = rig.connections.access.events
        let collector = Task { @MainActor in for await event in stream { events.append(event) } }
        let inlet = try await rig.connect("a@x")
        await rig.cadence.trigger(inlet.id, .mail)
        try await rig.connections.setup.remove(inlet.id)
        let seen = await until { events.contains(.inletRemoved(inlet.id)) }
        XCTAssertTrue(seen)
        collector.cancel()
        XCTAssertTrue(events.contains(.inletChanged(inlet.id)))
        XCTAssertTrue(events.contains(.syncFinished(.mail, inlet.id)))
        XCTAssertTrue(events.contains(.newItems(.mailboxes)))
    }

    @MainActor
    func testALostKeychainMarksTheInletAndTheStateIsKept() async throws {
        let database = try SQLiteStore.inMemory()
        let keychain = FakeKeychain()
        let first = try Rig.make(database: database, keychain: keychain)
        let inlet = try await first.connect("a@x")
        let lost = try Rig.make(database: database, provider: first.provider, keychain: FakeKeychain())
        XCTAssertTrue(lost.connections.setup.inlets[0].state.isConnected)
        XCTAssertThrowsError(try lost.connections.access.port((any PingPort).self, for: inlet.id)) {
            XCTAssertEqual($0 as? HubFailure, .notConnected(inlet.id))
        }
        XCTAssertEqual(lost.connections.setup.inlets[0].state, .keychainUnreadable)
        XCTAssertTrue(lost.connections.setup.inlets[0].state.canRenew)
        let back = try Rig.make(database: database, provider: first.provider, keychain: keychain)
        XCTAssertTrue(back.connections.setup.inlets[0].state.isConnected)
        do {
            _ = try await lost.connections.setup.probe(inlet.id)
            XCTFail("probe must throw")
        } catch {
            XCTAssertEqual(error, .probeFailed(Hint(text: "hint.keychain.unreadable", fixIn: .inlet(inlet.id))))
        }
        do {
            _ = try await lost.connections.setup.probe("nobody")
            XCTFail("probe must throw")
        } catch {
            XCTAssertEqual(error, .probeFailed(Hint(text: "hint.inlet.unknown", detail: "nobody")))
        }
    }

    @MainActor
    func testTheStartRunsEveryPlannedInletOnce() async throws {
        let database = try SQLiteStore.inMemory()
        let keychain = FakeKeychain()
        let first = try Rig.make(database: database, keychain: keychain)
        let a = try await first.connect("a@x")
        _ = try await first.connect("b@x")
        first.connections.rules.setCadence(a.id, .mail, .every(.seconds(300)))
        let second = try Rig.make(database: database, provider: first.provider, keychain: keychain)
        _ = await until { second.cadence.triggers > 0 }
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(second.cadence.triggers, 1)
        XCTAssertEqual(second.cadence.planned(a.id, .mail), .every(.seconds(300)))
        XCTAssertEqual(first.provider.ping.calls, 1)
    }

    @MainActor
    func testChangesTriggerTheSyncAndStopWithTheCadenceOrTheInlet() async throws {
        let rig = try Rig.make(deadlines: Deadlines(watchPause: .milliseconds(10)))
        let inlet = try await rig.connect("a@x")
        let provider = rig.provider
        let cadence = rig.cadence
        func wait(_ condition: @escaping @MainActor () -> Bool) async {
            let reached = await until(condition)
            XCTAssertTrue(reached)
        }
        rig.connections.rules.setCadence(inlet.id, .mail, .push)
        await wait { provider.changes.opened == 1 }
        provider.changes.push()
        await wait { cadence.triggers == 1 }
        rig.connections.rules.setCadence(inlet.id, .mail, .manual)
        await wait { provider.changes.ended == 1 }
        rig.connections.rules.setCadence(inlet.id, .mail, .every(.seconds(60)))
        await wait { provider.changes.opened == 2 }
        provider.changes.fail(URLError(.timedOut))
        await wait { provider.changes.opened == 3 }
        provider.changes.fail(FakeError.refused)
        await wait { provider.changes.ended == 3 }
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(provider.changes.opened, 3)
        rig.connections.rules.setCadence(inlet.id, .mail, .push)
        await wait { provider.changes.opened == 4 }
        try await rig.connections.setup.remove(inlet.id)
        await wait { provider.changes.ended == 4 }
    }

    @MainActor
    func testRenewedGrantIsStoredAndAFailedRenewalExpiresTheInlet() async throws {
        let rig = try Rig.make()
        let inlet = try await rig.connect("a@x")
        _ = try rig.connections.access.port((any PingPort).self, for: inlet.id)
        let renewal = try XCTUnwrap(rig.provider.renewals.with { $0.last })
        renewal.renewed(Grant(values: ["token": "fresh"]))
        let stored = await until { (try? rig.keychain.get(KeySlot(inlet: inlet.id, name: "token"))) == "fresh" }
        XCTAssertTrue(stored)
        XCTAssertTrue(rig.connections.setup.report(for: inlet.id).contains { $0.event == .renewal && $0.ok })
        renewal.failed(FakeError.auth)
        let expired = await until { rig.connections.setup.inlets[0].state.canRenew }
        XCTAssertTrue(expired)
        guard case .failed(let hint) = rig.connections.setup.inlets[0].state else { return XCTFail("state") }
        XCTAssertEqual(hint.text, Hint.signInExpiredText)
        XCTAssertEqual(hint.original?.code, "auth")
        XCTAssertThrowsError(try rig.connections.access.port((any PingPort).self, for: inlet.id)) {
            XCTAssertEqual($0 as? HubFailure, .notConnected(inlet.id))
        }
    }

    @MainActor
    func testPresetSetupAppliesTheDefaultCadences() async throws {
        let rig = try Rig.make(cadences: [.mail: .seconds(300)])
        let inlet = try await rig.connect("a@x")
        XCTAssertEqual(rig.connections.rules.cadence(inlet.id, .mail), .every(.seconds(300)))
        XCTAssertEqual(rig.cadence.planned(inlet.id, .mail), .every(.seconds(300)))
        XCTAssertEqual(rig.connections.setup.offers.map(\.id), ["fake.mail", "offer.fake"])
        XCTAssertEqual(rig.connections.setup.report(for: inlet.id).count, 1)
        let result = try await rig.connections.setup.probe(inlet.id)
        XCTAssertNil(result.rejection)
    }

    func testOffersDeriveFromProvidersByCapabilityAndPreset() {
        let person = Person(id: "p1", name: "P")
        let plain = FakeProvider(capabilities: [.mail])
        XCTAssertEqual(plain.offers(personal: .person(person.id)), [
            Offer(id: "offer.fake", provider: "fake", title: "offer.fake", capabilities: [.mail], owner: .person("p1"), way: .signIn)])
        let field = Field(id: "address", title: "address")
        let preset = Preset(id: "gmx", title: "GMX", values: ["server": "imap.example.test"])
        let withPreset = FakeProvider(capabilities: [.mail], form: [field], presets: [preset])
        XCTAssertEqual(withPreset.offers(personal: .person(person.id)), [
            Offer(id: "offer.fake.gmx", provider: "fake", title: "GMX", capabilities: [.mail], owner: .person("p1"),
                  way: .form([field]), preset: preset)])
        XCTAssertEqual(FakeProvider(capabilities: [.files]).offers(personal: .person(person.id)), [])
    }

    func testRenewalEnginePicksTheOfferByTitleAndFillsTheAccountField() {
        let one = Offer(id: "a", provider: "fake", title: "One", capabilities: [.mail], owner: .company, way: .signIn)
        let two = Offer(id: "b", provider: "fake", title: "Two", capabilities: [.mail], owner: .company,
                        way: .form([Field(id: "user", title: "user", holdsAccount: true), Field(id: "host", title: "host")]),
                        preset: Preset(id: "p", title: "Two", values: ["host": "h"]))
        let failed = Inlet(id: "i", provider: "fake", capabilities: [.mail], owner: .company, title: "Two", account: "me@x",
                           state: .failed(Hint(text: "x")))
        let fine = Inlet(id: "j", provider: "fake", capabilities: [.mail], owner: .company, title: "Two", account: "me@x")
        XCTAssertEqual(RenewalEngine.renewal(of: "i", inlets: [failed], offers: [one, two]),
                       Renewal(offer: two, values: ["host": "h", "user": "me@x", Input.expectedAccountKey: "me@x"]))
        XCTAssertEqual(RenewalEngine.renewal(of: "i", inlets: [Inlet(id: "i", provider: "fake", capabilities: [.mail], owner: .company,
                                                                       title: "Else", account: "q", state: .keychainUnreadable)],
                                            offers: [one, two])?.offer, one)
        XCTAssertNil(RenewalEngine.renewal(of: "j", inlets: [fine], offers: [one, two]))
        XCTAssertNil(RenewalEngine.renewal(of: "i", inlets: [failed], offers: []))
        XCTAssertNil(RenewalEngine.renewal(of: "zz", inlets: [failed], offers: [one]))
    }

    func testKeyChecksMapStatusShapeAndFieldFailures() async throws {
        func provider(_ body: @escaping @Sendable (KeyValues) async throws -> String?) throws -> KeyAccess {
            try XCTUnwrap(KeyAccess.all(checks: [StubCheck(integration: "clickup", body: body)], catalog: .standard).first)
        }
        let inlet = Inlet(id: "i", provider: "clickup", capabilities: [], owner: .company, title: "t", account: "old")
        let grant = Grant(values: ["token": "abc"])
        let named = try await provider { $0["token"] == "abc" ? "alice" : nil }.probe.probe(inlet, grant)
        XCTAssertEqual(named, ProbeResult(account: "alice"))
        let unnamed = try await provider { _ in nil }.probe.probe(inlet, grant)
        XCTAssertEqual(unnamed.account, "clickup")
        let missing = try await provider { _ in "x" }.probe.probe(inlet, Grant(values: [:]))
        XCTAssertEqual(missing.rejection, Hint(text: "hint.key.fields.invalid", fixIn: .inlet("i")))
        let denied = try await provider { _ in throw StatusFailure(status: 401) }.probe.probe(inlet, grant)
        XCTAssertEqual(denied.rejection?.text, "hint.key.rejected")
        XCTAssertEqual(denied.rejection?.kind, .signIn)
        XCTAssertEqual(denied.rejection?.original?.status, 401)
        let absent = try await provider { _ in throw StatusFailure(status: 404) }.probe.probe(inlet, grant)
        XCTAssertEqual(absent.rejection?.text, "hint.key.failed")
        XCTAssertEqual(absent.rejection?.kind, .rejected)
        let shape = try await provider { _ in throw ShapeFailure() }.probe.probe(inlet, grant)
        XCTAssertEqual(shape.rejection?.text, "hint.key.failed")
        let field = try await provider { _ in throw KeyFieldFailure(field: "user") }.probe.probe(inlet, grant)
        XCTAssertEqual(field.rejection?.detail, "user")
        let busy = try provider { _ in throw StatusFailure(status: 503) }
        do {
            _ = try await busy.probe.probe(inlet, grant)
            XCTFail("probe must throw")
        } catch {
            XCTAssertEqual(busy.classify(error).kind, .transient)
            XCTAssertEqual(busy.classify(error).original, Original(provider: "clickup", status: 503))
        }
        do {
            _ = try await provider { _ in throw FakeError.down }.probe.probe(inlet, grant)
            XCTFail("probe must throw")
        } catch {
            XCTAssertEqual(error as? FakeError, .down)
        }
        do {
            _ = try await provider { _ in throw CancellationError() }.probe.probe(inlet, grant)
            XCTFail("probe must throw")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertEqual(busy.classify(URLError(.timedOut)).kind, .transient)
        for (status, kind) in [(401, FailureKind.signIn), (403, .signIn), (408, .transient), (429, .transient), (500, .transient),
                               (599, .transient), (400, .rejected), (404, .rejected), (600, .rejected)] {
            XCTAssertEqual(HttpStatus(code: status).kind, kind, String(status))
        }
        XCTAssertNil(HttpStatus.of(FakeError.down))
        XCTAssertEqual(HttpStatus.of(StatusFailure(status: 7)), HttpStatus(code: 7))
    }

    @MainActor
    func testKeyAccessConnectsThroughTheHubAndTrimsTheFields() async throws {
        let checks: [any ConnectionCheckPort] = [
            StubCheck(integration: "clickup", body: { _ in "alice" }),
            StubCheck(integration: "airtable", body: { values in
                guard values["base"] == "appABCDEFGHIJKLMN" else { throw KeyFieldFailure(field: "base") }
                return nil
            }),
            StubCheck(integration: "unknown", body: { _ in nil }),
        ]
        let providers = KeyAccess.all(checks: checks, catalog: .standard)
        XCTAssertEqual(providers.map(\.id), ["airtable", "clickup"])
        let rig = try Rig.make(offers: [], providers: providers)
        let offers = rig.connections.setup.offers
        XCTAssertEqual(offers.map(\.id), ["offer.airtable", "offer.clickup"])
        XCTAssertEqual(offers.map(\.owner), [.company, .person("p1")])
        guard case .key(let fields) = offers[1].way else { return XCTFail("way") }
        XCTAssertEqual(fields, [Field(id: "token", title: "settings.service.clickup.field.token", secret: true)])
        let inlet = try await rig.connections.setup.add(offers[1], input: .fields(["token": "  abc \n"]))
        XCTAssertEqual(inlet.account, "alice")
        XCTAssertEqual(try rig.keychain.get(KeySlot(inlet: inlet.id, name: "token")), "abc")
        do {
            _ = try await rig.connections.setup.add(offers[0], input: .fields(["base": "bad", "token": "t"]))
            XCTFail("add must throw")
        } catch {
            guard case .probeFailed(let hint) = error else { return XCTFail("error \(error)") }
            XCTAssertEqual(hint.text, "hint.key.fields.invalid")
            XCTAssertEqual(hint.detail, "base")
        }
        let company = try await rig.connections.setup.add(offers[0], input: .fields(["base": "appABCDEFGHIJKLMN", "token": "t"]))
        XCTAssertEqual(company.owner, .company)
        XCTAssertEqual(company.account, "airtable")
        let readings = IntegrationReadEngine.readAll(.standard, setup: rig.connections.setup, rules: rig.connections.rules)
        XCTAssertEqual(readings.map(\.state).filter { $0 == .connected }.count, 2)
        XCTAssertEqual(IntegrationReadEngine.badCount(readings), 0)
        let held = IntegrationReadEngine.values(of: try XCTUnwrap(readings.first { $0.info.id == "airtable" }), keychain: rig.keychain)
        XCTAssertEqual(held, IntegrationValues(text: ["base": "appABCDEFGHIJKLMN"], held: ["base", "token"]))
        XCTAssertEqual(IntegrationReadEngine.values(of: try XCTUnwrap(readings.first { $0.info.id == "sevdesk" }), keychain: rig.keychain), .none)
    }

    @MainActor
    func testClaudeCredentialReadsTheKeyAndFallsBackToTheDefaultModel() async throws {
        let providers = KeyAccess.all(checks: [StubCheck(integration: "claude", body: { _ in nil })], catalog: .standard)
        let rig = try Rig.make(offers: [], providers: providers)
        let credential = ClaudeCredential(setup: rig.connections.setup, keychain: rig.keychain)
        XCTAssertNil(credential.current())
        let offer = try XCTUnwrap(rig.connections.setup.offers.first)
        let inlet = try await rig.connections.setup.add(offer, input: .fields(["key": "sk-test", "model": ""]))
        XCTAssertEqual(credential.current(), ClaudeKey(apiKey: "sk-test", model: ClaudeKey.defaultModel))
        try rig.keychain.put("other-model", at: KeySlot(inlet: inlet.id, name: "model"))
        XCTAssertEqual(credential.current(), ClaudeKey(apiKey: "sk-test", model: "other-model"))
        rig.keychain.setUnreadable(true)
        XCTAssertNil(credential.current())
        rig.keychain.setUnreadable(false)
        try await rig.connections.setup.remove(inlet.id)
        XCTAssertNil(credential.current())
    }

    @MainActor
    func testIntegrationReadingListsEveryAccountsAreasAndNamesTheLeadAddress() async throws {
        let info = IntegrationInfo(
            id: "fake", access: .password, companyOwned: false, fields: [],
            areas: [IntegrationArea(id: "mail", capability: .mail)], extras: [], listsAccounts: false, providers: ["fake"], logo: nil)
        let rig = try Rig.make()
        let first = try await rig.connect("a@x")
        let second = try await rig.connect("b@x")
        rig.connections.rules.setCadence(second.id, .mail, .every(.seconds(300)))
        let reading = IntegrationReadEngine.read(info, setup: rig.connections.setup, rules: rig.connections.rules)
        XCTAssertEqual(reading.areas.map(\.inlet), [first.id, second.id])
        XCTAssertEqual(reading.areas.map(\.account), ["a@x", "b@x"])
        XCTAssertEqual(reading.areas.map(\.choice), [.manual, .minutes5])
        XCTAssertEqual(Set(reading.areas.map(\.id)).count, 2)
        XCTAssertEqual(reading.lead?.id, first.id)
        XCTAssertEqual(reading.leadAddress, "a@x")
        try await rig.connections.setup.remove(first.id)
        let remaining = IntegrationReadEngine.read(info, setup: rig.connections.setup, rules: rig.connections.rules)
        XCTAssertEqual(remaining.leadAddress, "b@x")
        XCTAssertEqual(remaining.areas.map(\.inlet), [second.id])
    }

    @MainActor
    func testIntegrationReadingDerivesStateNoteAreasAndStep() async throws {
        let info = IntegrationInfo(
            id: "fake", access: .password, companyOwned: false,
            fields: [IntegrationField(id: "token", secret: true), IntegrationField(id: "address", secret: false)],
            areas: [IntegrationArea(id: "mail", capability: .mail), IntegrationArea(id: "projects", capability: nil),
                    IntegrationArea(id: "files", capability: .files)],
            extras: [], listsAccounts: false, providers: ["fake"], logo: nil)
        let rig = try Rig.make()
        let empty = IntegrationReadEngine.read(info, setup: rig.connections.setup, rules: rig.connections.rules)
        XCTAssertEqual(empty.state, .notConnected)
        XCTAssertEqual(empty.step, .add([Rig.offer, Offer(id: "offer.fake", provider: "fake", title: "offer.fake", capabilities: [.mail],
                                                           owner: .person("p1"), way: .signIn)]))
        let inlet = try await rig.connect("a@x")
        rig.connections.rules.setCadence(inlet.id, .mail, .every(.seconds(300)))
        await rig.cadence.trigger(inlet.id, .mail)
        let reading = IntegrationReadEngine.read(info, setup: rig.connections.setup, rules: rig.connections.rules)
        XCTAssertEqual(reading.state, .connected)
        XCTAssertEqual(reading.step, .check(inlet.id))
        XCTAssertTrue(reading.asksReconnect)
        guard case .checked? = reading.note else { return XCTFail("note \(String(describing: reading.note))") }
        XCTAssertEqual(reading.areas.map(\.id), [inlet.id + "|mail"])
        XCTAssertEqual(reading.areas.first?.choice, .minutes5)
        XCTAssertNotNil(reading.areas.first?.lastSync)
        XCTAssertEqual(reading.areas.first?.running, false)
        let held = IntegrationReadEngine.values(of: reading, keychain: rig.keychain)
        XCTAssertEqual(held.held, ["token"])
        XCTAssertEqual(held.text, [:])
        rig.provider.setAccepting(false)
        _ = try? await rig.connections.setup.probe(inlet.id)
        let failed = IntegrationReadEngine.read(info, setup: rig.connections.setup, rules: rig.connections.rules)
        XCTAssertEqual(failed.state, .failed)
        XCTAssertEqual(failed.step, .renew(inlet.id))
        XCTAssertEqual(failed.hint, Hint(text: "hint.fake.rejected"))
        guard case .failed(let at, let lastOK)? = failed.note else { return XCTFail("note") }
        XCTAssertNotNil(at)
        XCTAssertNotNil(lastOK)
        XCTAssertEqual(IntegrationReadEngine.failedCount([failed, reading]), 1)
        XCTAssertEqual(IntegrationReadEngine.badCount([failed, reading]), 1)
    }

    func testLinkStateMapsAndCombinesBySeverity() {
        XCTAssertEqual(LinkState(.created), .notConnected)
        XCTAssertEqual(LinkState(.locked), .notConnected)
        XCTAssertEqual(LinkState(.signedIn), .stored)
        XCTAssertEqual(LinkState(.connecting), .connecting)
        XCTAssertEqual(LinkState(.connected(probed: .distantPast)), .connected)
        XCTAssertEqual(LinkState(.working), .working)
        XCTAssertEqual(LinkState(.failed(Hint(text: "x"))), .failed)
        XCTAssertEqual(LinkState(.keychainUnreadable), .unreadable)
        XCTAssertEqual(LinkState(.orphaned), .orphaned)
        XCTAssertEqual(LinkState.combined([]), .notConnected)
        XCTAssertEqual(LinkState.combined([.connected, .failed, .stored]), .failed)
        XCTAssertEqual(LinkState.combined([.connected, .unreadable]), .unreadable)
        XCTAssertEqual(LinkState.combined([.notConnected, .connected]), .connected)
        XCTAssertEqual(LinkState.allCases.filter(\.isBad), [.failed, .unreadable])
        XCTAssertEqual(LinkState.allCases.filter(\.isActive), [.connected, .stored, .working])
        XCTAssertEqual(LinkState.allCases.filter(\.canDisconnect), [.connected, .stored, .working, .failed])
        XCTAssertEqual(Set(LinkState.allCases.map(\.key)).count, LinkState.allCases.count)
    }

    func testCadenceChoiceRoundTripsAndKeysAreUnique() {
        for choice in CadenceChoice.allCases { XCTAssertEqual(CadenceChoice(choice.cadence), choice) }
        XCTAssertNil(CadenceChoice(.every(.seconds(7))))
        XCTAssertNil(CadenceChoice(.push))
        XCTAssertEqual(CadenceChoice.minutes5.cadence, .every(.seconds(300)))
        XCTAssertEqual(Set(CadenceChoice.allCases.map(\.key)).count, CadenceChoice.allCases.count)
        let data = try? JSONEncoder().encode(Cadence.every(.seconds(60)))
        XCTAssertEqual(data.flatMap { try? JSONDecoder().decode(Cadence.self, from: $0) }, .every(.seconds(60)))
    }

    func testASignInMailAccountIsRenewedThroughItsOwnOfferWithTheAddressAsHint() {
        let imap = Offer(id: "offer.imap", provider: "imap", title: "IMAP", capabilities: [.mail], owner: .person("p1"),
                         way: .form([Field(id: "address", title: "address", holdsAccount: true)]))
        let outlook = Offer(id: "offer.microsoft", provider: "microsoft", title: "offer.microsoft", capabilities: [.mail],
                            owner: .person("p1"), way: .signIn)
        var inlet = Inlet(id: "microsoft-1", provider: "microsoft", capabilities: [.mail], owner: .person("p1"),
                          title: "offer.microsoft")
        inlet.account = "me@outlook.com"
        inlet.state = .failed(Hint(text: "hint.signin.expired", kind: .signIn))
        let renewal = RenewalEngine.renewal(of: inlet.id, inlets: [inlet], offers: [imap, outlook])
        XCTAssertEqual(renewal?.offer, outlook)
        XCTAssertEqual(renewal?.values, [Input.expectedAccountKey: "me@outlook.com"])
    }

    func testCatalogLookupsAndInventory() {
        let catalog = IntegrationCatalogStore.standard
        XCTAssertEqual(catalog.info("google")?.providers, ["google"])
        XCTAssertEqual(catalog.info(forProvider: "imap")?.id, "mailaccounts")
        XCTAssertEqual(catalog.info(forProvider: "microsoft")?.id, "mailaccounts")
        XCTAssertEqual(catalog.info("mailaccounts")?.providers, ["imap", "microsoft"])
        XCTAssertNil(catalog.info("unknown"))
        XCTAssertEqual(Set(catalog.entries.map(\.id)).count, catalog.entries.count)
        let info = catalog.info("clockodo")
        XCTAssertEqual(info?.nameKey, "settings.service.clockodo.name")
        XCTAssertEqual(info?.useKey, "settings.service.clockodo.use")
        XCTAssertEqual(info?.fields.first.map { info?.fieldKey($0) }, "settings.service.clockodo.field.email")
        XCTAssertEqual(catalog.info("google")?.areas.first.map { catalog.info("google")?.areaKey($0) }, "settings.service.google.area.mail")
        XCTAssertEqual(catalog.info("google")?.extras.first.map { catalog.info("google")?.extraKey($0) }, "settings.service.google.extra.driveFolders")
        XCTAssertEqual(catalog.info("claude")?.fields.last?.fallbackKey, "settings.value.default")
        XCTAssertEqual(IntegrationAccess.emailKey.key, "settings.access.emailKey")
        let secrets: Set<String> = ["key", "password", "secret", "token"]
        for entry in catalog.entries {
            for field in entry.fields { XCTAssertEqual(field.secret, secrets.contains(field.id), entry.id + "." + field.id) }
        }
        XCTAssertEqual(catalog.entries.filter(\.companyOwned).map(\.id), ["airtable", "sevdesk", "dhl", "dhlship"])
    }

    func testSettingsVocabularyCoversEveryGroupWithUniqueKeys() {
        XCTAssertEqual(Set(SettingsSection.allCases.map(\.group)), Set(SettingsGroup.allCases))
        XCTAssertEqual(SettingsGroup.allCases.flatMap(\.sections).count, SettingsSection.allCases.count)
        let keys = SettingsGroup.allCases.map(\.key) + SettingsSection.allCases.flatMap { [$0.key, $0.detailKey] }
            + SettingsLabel.allCases.map(\.key) + CompanyEntry.allCases.map(\.key) + ImprintEntry.allCases.map(\.key)
            + LockDelay.allCases.map(\.key) + StartDestination.allCases.map(\.key)
        XCTAssertEqual(Set(keys).count, keys.count)
        XCTAssertEqual(SettingsSection.allCases.map(\.id), SettingsSection.allCases.map(\.rawValue))
        XCTAssertEqual(StartDestination.stored(nil), .mail)
        XCTAssertEqual(StartDestination.stored("nonsense"), .mail)
        XCTAssertEqual(StartDestination.stored("lastOpen"), .lastOpen)
        XCTAssertEqual([StartDestination.mail, .settings, .lastOpen].map(\.appID), ["mail", "settings", nil])
        XCTAssertEqual(CompanyEntry.address.storageKey, SettingsKey.companyEntry("address"))
        XCTAssertEqual(ImprintEntry.rights.storageKey, "settings.imprint.rights")
        XCTAssertEqual(AppearanceChoice.allCases.count, 3)
    }

    @MainActor
    func testSettingsStatePersistsEveryChoiceAndStartsWithDefaults() throws {
        let database = try SQLiteStore.inMemory()
        let state = try SettingsState(settings: SettingStore(database: database))
        XCTAssertEqual(state.appearance, .system)
        XCTAssertEqual(state.destination, .mail)
        XCTAssertTrue(state.lockOn)
        XCTAssertEqual(state.lockDelay, .minutes5)
        XCTAssertEqual(state.privacy, PrivacyChoices(loadImages: false, assistantOff: false, chatFiles: true))
        XCTAssertEqual(state.profile, UserProfile())
        XCTAssertEqual(state.company["name"], "")
        state.setAppearance(.dark)
        state.setDestination(.lastOpen)
        state.setLockOn(false)
        state.setLockDelay(.immediately)
        state.updatePrivacy { $0.loadImages = true; $0.chatFiles = false; $0.assistantOff = true }
        state.updateProfile { $0.name = "Anna Berg"; $0.role = "Lead"; $0.code = "AB"; $0.phone = "123"; $0.birthdays = true }
        state.setCompany(.address, "Street 1")
        state.setImprint(.signature, "Anna")
        let again = try SettingsState(settings: SettingStore(database: database))
        XCTAssertEqual(again.appearance, .dark)
        XCTAssertEqual(again.destination, .lastOpen)
        XCTAssertFalse(again.lockOn)
        XCTAssertEqual(again.lockDelay, .immediately)
        XCTAssertEqual(again.privacy, PrivacyChoices(loadImages: true, assistantOff: true, chatFiles: false))
        XCTAssertEqual(again.profile, UserProfile(name: "Anna Berg", role: "Lead", code: "AB", phone: "123", birthdays: true))
        XCTAssertEqual(again.company["address"], "Street 1")
        XCTAssertEqual(again.company["name"], "")
        XCTAssertEqual(again.imprint["signature"], "Anna")
        try database.write { db in
            try db.execute(sql: "UPDATE setting SET value = ? WHERE key = ?", arguments: [Data("garbage".utf8), SettingsKey.appearance])
        }
        XCTAssertEqual(try SettingsState(settings: SettingStore(database: database)).appearance, .system)
    }

    @MainActor
    func testMailboxDisplayIsStoredPerMailbox() throws {
        let database = try SQLiteStore.inMemory()
        let state = try SettingsState(settings: SettingStore(database: database))
        XCTAssertEqual(state.display("gmail-a"), .ownName)
        state.setDisplay(.domain, for: "gmail-a")
        state.setDisplay(.localPart, for: "imap-b")
        let again = try SettingsState(settings: SettingStore(database: database))
        XCTAssertEqual(again.display("gmail-a"), .domain)
        XCTAssertEqual(again.display("imap-b"), .localPart)
        XCTAssertEqual(again.display("other"), .ownName)
        try database.write { db in
            try db.execute(sql: "UPDATE setting SET value = ? WHERE key = ?",
                           arguments: [Data("garbage".utf8), SettingsKey.mailboxDisplay("gmail-a")])
        }
        XCTAssertEqual(try SettingsState(settings: SettingStore(database: database)).display("gmail-a"), .ownName)
        state.setDisplay(.domain, for: "gmail-a")
        state.setDisplay(.domain, for: "gmail-ab")
        state.forget("gmail-a")
        XCTAssertEqual(state.display("gmail-a"), .ownName)
        XCTAssertEqual(state.display("gmail-ab"), .domain)
        let reloaded = try SettingsState(settings: SettingStore(database: database))
        XCTAssertEqual(reloaded.display("gmail-a"), .ownName)
        XCTAssertEqual(reloaded.display("gmail-ab"), .domain)
        XCTAssertEqual(reloaded.display("imap-b"), .localPart)
    }

    @MainActor
    func testMailboxRangeIsStoredPerMailboxAndIgnoresOldValues() throws {
        let database = try SQLiteStore.inMemory()
        let store = SettingStore(database: database)
        let state = try SettingsState(settings: store)
        XCTAssertEqual(state.range("gmail-a"), .days30)
        state.setRange(.year, for: "gmail-a")
        state.setRange(.all, for: "gmail-ab")
        try store.store("latest500", forKey: SettingsKey.mailboxRange("imap-b"))
        let again = try SettingsState(settings: store)
        XCTAssertEqual(again.range("gmail-a"), .year)
        XCTAssertEqual(again.range("gmail-ab"), .all)
        XCTAssertEqual(again.range("imap-b"), .days30)
        state.forget("gmail-a")
        XCTAssertEqual(state.range("gmail-a"), .days30)
        XCTAssertEqual(try SettingsState(settings: store).range("gmail-ab"), .all)
        XCTAssertEqual(MailboxRange.year.key, "settings.account.range.year")
    }

    func testMailboxDisplayShowsNameOrAddressPart() {
        XCTAssertEqual(MailboxDisplay.ownName.text(title: " Arbeit ", account: "info@example.com"), "Arbeit")
        XCTAssertEqual(MailboxDisplay.ownName.text(title: "  ", account: "info@example.com"), "info@")
        XCTAssertEqual(MailboxDisplay.localPart.text(title: "Arbeit", account: "info@example.com"), "info@")
        XCTAssertEqual(MailboxDisplay.domain.text(title: "Arbeit", account: "info@example.com"), "@example.com")
        XCTAssertEqual(MailboxDisplay.local("plain"), "plain@")
        XCTAssertEqual(MailboxDisplay.domain("plain"), "@plain")
        XCTAssertEqual(MailboxDisplay.domain("@example.com"), "@example.com")
        XCTAssertEqual(MailboxDisplay.allCases, [.ownName, .localPart, .domain])
        XCTAssertEqual(MailboxDisplay.ownName.choice(title: " Arbeit ", account: "info@example.com"), "Arbeit")
        XCTAssertNil(MailboxDisplay.ownName.choice(title: "  ", account: "info@example.com"))
        XCTAssertEqual(MailboxDisplay.localPart.choice(title: "Arbeit", account: "info@example.com"), "info@")
        XCTAssertEqual(MailboxDisplay.domain.choice(title: "Arbeit", account: "info@example.com"), "@example.com")
    }

    @MainActor
    func testSettingsStateShowsOneCardAndOpensTheGroupsFirstCard() throws {
        let state = try SettingsState(settings: SettingStore(database: SQLiteStore.inMemory()))
        XCTAssertEqual(state.group, .connections)
        XCTAssertEqual(state.cards, ["google"])
        state.toggleFan()
        XCTAssertTrue(state.fanned)
        for id in ["a", "b", "c"] { state.open(id) }
        XCTAssertEqual(state.cards, ["c"])
        XCTAssertEqual(state.front, "c")
        XCTAssertFalse(state.fanned)
        state.select(.company)
        XCTAssertEqual(state.group, .company)
        XCTAssertEqual(state.cards, ["companyData"])
        state.select(.folders)
        XCTAssertEqual(state.cards, ["folders"])
        XCTAssertEqual(SettingsGroup.folders.sections, [.folders, .templates])
        state.toggleFan()
        XCTAssertTrue(state.fanned)
        state.bring("folders")
        XCTAssertFalse(state.fanned)
        state.close("folders")
        XCTAssertNil(state.front)
        XCTAssertEqual(state.cards, [])
        state.notify("settings.toast.copied", name: "n")
        XCTAssertEqual([state.toast, state.toastName], ["settings.toast.copied", "n"])
        let serial = state.toastSerial
        state.notify("settings.toast.copied", name: "n")
        XCTAssertEqual(state.toastSerial, serial + 1)
        state.dismissToast()
        XCTAssertNil(state.toast)
        XCTAssertNil(state.toastName)
    }

    @MainActor
    func testSignOutRemovesEveryInletAndReportsTheOnesThatStay() async throws {
        let rig = try Rig.make()
        let a = try await rig.connect("a@x")
        let b = try await rig.connect("b@x")
        rig.keychain.failDeletes(after: 0)
        let stuck = await SignOutEngine.run(setup: rig.connections.setup)
        XCTAssertEqual(stuck.count, 2)
        XCTAssertEqual(Set(rig.connections.setup.inlets.map(\.id)), [a.id, b.id])
        rig.keychain.failDeletes(after: nil)
        let done = await SignOutEngine.run(setup: rig.connections.setup)
        XCTAssertEqual(done, [])
        XCTAssertEqual(rig.connections.setup.inlets, [])
        XCTAssertTrue(rig.keychain.slots.isEmpty)
    }

    func testTimerCadenceTriggersExactlyOnceAfterTheTick() async throws {
        let ticker = Ticker()
        let counter = Counter()
        let cadence = TimerCadence(sleep: { await ticker.sleep($0) })
        cadence.attach { inlet, capability in
            await counter.run()
            return SyncReport(inlet: inlet, capability: capability, result: .finished(items: 0))
        }
        cadence.plan("i1", .mail, .every(.seconds(300)))
        func wait(_ condition: @escaping @Sendable () async -> Bool) async -> Bool {
            for _ in 0..<400 {
                if await condition() { return true }
                try? await Task.sleep(for: .milliseconds(5))
            }
            return await condition()
        }
        let armed = await wait { await ticker.waiters == 1 }
        XCTAssertTrue(armed)
        let requested = await ticker.requested
        XCTAssertEqual(requested, [.seconds(300)])
        let before = await counter.calls
        XCTAssertEqual(before, 0)
        await ticker.tick()
        let fired = await wait { await counter.calls == 1 }
        XCTAssertTrue(fired)
        let rearmed = await wait { await ticker.waiters == 1 }
        XCTAssertTrue(rearmed)
        try await Task.sleep(for: .milliseconds(30))
        let after = await counter.calls
        XCTAssertEqual(after, 1)
        cadence.plan("i1", .mail, .off)
    }

    func testTimerCadenceSkipsASecondTriggerDuringARun() async throws {
        let counter = Counter()
        await counter.block()
        let cadence = TimerCadence(sleep: { _ in try await Task.sleep(for: .seconds(3600)) })
        cadence.attach { inlet, capability in
            await counter.run()
            return SyncReport(inlet: inlet, capability: capability, result: .finished(items: 0))
        }
        let first = Task { await cadence.trigger("i1", .mail) }
        for _ in 0..<400 {
            if await counter.calls == 1 { break }
            try await Task.sleep(for: .milliseconds(5))
        }
        let started = await counter.calls
        XCTAssertEqual(started, 1)
        await cadence.trigger("i1", .mail)
        let during = await counter.calls
        XCTAssertEqual(during, 1)
        await cadence.trigger("i2", .mail)
        let other = await counter.calls
        XCTAssertEqual(other, 2)
        await counter.release()
        await first.value
        await cadence.trigger("i1", .mail)
        let again = await counter.calls
        XCTAssertEqual(again, 3)
    }

    func testTimerCadenceStopsWhenReplannedWithoutAnInterval() async throws {
        let ticker = Ticker()
        let counter = Counter()
        let cadence = TimerCadence(sleep: { await ticker.sleep($0) })
        cadence.attach { inlet, capability in
            await counter.run()
            return SyncReport(inlet: inlet, capability: capability, result: .skipped)
        }
        cadence.plan("i1", .mail, .every(.seconds(10)))
        for _ in 0..<400 {
            if await ticker.waiters == 1 { break }
            try await Task.sleep(for: .milliseconds(5))
        }
        cadence.plan("i1", .mail, .manual)
        await ticker.tick()
        try await Task.sleep(for: .milliseconds(30))
        let calls = await counter.calls
        XCTAssertEqual(calls, 0)
    }

    func testCostStoreKeepsOneRowPerInletCapabilityAndDay() throws {
        let database = try SQLiteStore.inMemory()
        let cost = CostStore(database: database)
        func date(_ day: Int, hour: Int = 12) -> Date { Date(timeIntervalSince1970: TimeInterval(day * 86_400 + hour * 3_600)) }
        cost.book(CostItem(inlet: "a", capability: .mail, cost: Cost(calls: 1, bytes: 10), at: date(5, hour: 1)))
        cost.book(CostItem(inlet: "a", capability: .mail, cost: Cost(calls: 2, bytes: 5, tokens: 3), at: date(5, hour: 23)))
        cost.book(CostItem(inlet: "a", capability: .mail, cost: Cost(calls: 1), at: date(6)))
        cost.book(CostItem(inlet: "a", capability: .files, cost: Cost(calls: 1), at: date(6)))
        let rows = try database.read { db in try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM cost_day") }
        XCTAssertEqual(rows, 3)
        let (calls, bytes, tokens) = try database.read { db -> (Int, Int, Int) in
            let row = try Row.fetchOne(db, sql: "SELECT calls, bytes, tokens FROM cost_day WHERE inlet = 'a' AND capability = 'mail' AND day = 5")
            return (row?["calls"] ?? 0, row?["bytes"] ?? 0, row?["tokens"] ?? 0)
        }
        XCTAssertEqual([calls, bytes, tokens], [3, 15, 3])
        XCTAssertEqual(CostStore.day(of: date(5, hour: 0)), 5)
    }

    func testKeychainNamesFollowPrefixAndInlet() {
        let slot = KeySlot(inlet: "imap-123", name: "password")
        XCTAssertEqual(KeychainStore.service(for: slot, prefix: "p."), "p.hub.imap-123")
        XCTAssertEqual(KeychainStore.service(for: slot), AppIdentity.keychainPrefix + "hub.imap-123")
        XCTAssertEqual(KeychainStore.account(for: slot), "password")
        let a = KeySlot(inlet: "x", name: "a")
        let b = KeySlot(inlet: "x", name: "b")
        XCTAssertEqual(KeychainStore.service(for: a), KeychainStore.service(for: b))
        XCTAssertNotEqual(KeychainStore.account(for: a), KeychainStore.account(for: b))
        XCTAssertNotEqual(KeychainStore.service(for: a), KeychainStore.service(for: KeySlot(inlet: "y", name: "a")))
    }

    func testKeychainStoreRoundTripsAndForgets() throws {
        let store = KeychainStore(prefix: "com.johannesleoberger.alfaos.test." + UUID().uuidString + ".")
        let slot = KeySlot(inlet: "probe", name: "token")
        XCTAssertNil(try store.get(slot))
        try store.put("one", at: slot)
        XCTAssertEqual(try store.get(slot), "one")
        try store.put("two", at: slot)
        XCTAssertEqual(try store.get(slot), "two")
        try store.delete(slot)
        XCTAssertNil(try store.get(slot))
        try store.delete(slot)
    }

    func testSettingStoreRemovesByLiteralPrefix() throws {
        let store = SettingStore(database: try SQLiteStore.inMemory())
        for key in ["a_b|1", "axb|1", "a%|2", "a%c|3", "z"] { try store.put(key, Data([1])) }
        try store.remove(withPrefix: "a_")
        XCTAssertEqual(Set(try store.all().keys), ["axb|1", "a%|2", "a%c|3", "z"])
        try store.remove(withPrefix: "a%")
        XCTAssertEqual(Set(try store.all().keys), ["axb|1", "z"])
        try store.put("ax", Data([1]))
        try store.remove(key: "ax")
        XCTAssertEqual(Set(try store.all().keys), ["axb|1", "z"])
        try store.store(5, forKey: "n")
        XCTAssertEqual(SettingStore.decoded(try store.all()["n"], as: Int.self), 5)
        XCTAssertNil(SettingStore.decoded(Data("x".utf8), as: Int.self))
        XCTAssertNil(SettingStore.decoded(nil, as: Int.self))
    }

    func testDeadlineEndsOnceAndExpires() async throws {
        let quick = try await Deadline.run(.seconds(5)) { 7 }
        XCTAssertEqual(quick, 7)
        do {
            _ = try await Deadline.run(.milliseconds(30)) { () -> Int in
                try await Task.sleep(for: .seconds(5))
                return 1
            }
            XCTFail("deadline must expire")
        } catch {
            XCTAssertTrue(error is DeadlineExpired)
        }
        do {
            _ = try await Deadline.run(.seconds(5)) { () -> Int in throw FakeError.down }
            XCTFail("work must throw")
        } catch {
            XCTAssertEqual(error as? FakeError, .down)
        }
        let task = Task {
            try await Deadline.run(.seconds(5)) { () -> Int in
                try await Task.sleep(for: .seconds(5))
                return 2
            }
        }
        try await Task.sleep(for: .milliseconds(30))
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("task must be cancelled")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }

    func testHintsKeepTheOriginalAndGenericClassificationFollowsTheError() {
        let original = Original(provider: "gmail", status: 403, code: "limit", text: "slow down", extra: ["domain": "usage"])
        let hint = Hint(text: "hint.provider.transient", classification: Classification(kind: .transient, original: original))
        XCTAssertEqual(hint.code, "gmail.403.limit")
        XCTAssertEqual(hint.codeKey, "hint.code.gmail.403.limit")
        XCTAssertEqual(hint.detail, "slow down")
        XCTAssertEqual(Original(provider: "imap").label, "imap")
        XCTAssertEqual(Classification(kind: .rejected, original: Original(provider: "x", status: 500)).detail, "HTTP 500")
        XCTAssertNil(Classification(kind: .rejected, original: Original(provider: "x")).detail)
        XCTAssertEqual(Classification.generic(URLError(.timedOut)).kind, .transient)
        XCTAssertEqual(Classification.generic(URLError(.timedOut)).original.code, "URLError.-1001")
        XCTAssertEqual(Classification.generic(FakeError.down).kind, .rejected)
        XCTAssertEqual(Hint.failed(FakeError.down), Hint(text: "hint.provider.failed", detail: "down"))
        XCTAssertEqual(HintEngine.hint(Classification(kind: .signIn, original: original), fixIn: .inlet("a")).text, Hint.signInExpiredText)
        XCTAssertNil(Hint(text: "plain").code)
        let data = try? JSONEncoder().encode(hint)
        XCTAssertEqual(data.flatMap { try? JSONDecoder().decode(Hint.self, from: $0) }, hint)
    }

    func testSetupFailuresCarryTheirWordsAndDetails() {
        XCTAssertEqual(SetupFailure.cancelled.hint.text, "hub.error.cancelled")
        XCTAssertEqual(SetupFailure.duplicate.hint.text, "hub.error.duplicate")
        XCTAssertEqual(SetupFailure.keychain(-25_300).hint, Hint(text: "hub.error.keychain", detail: "-25300"))
        let rejection = Hint(text: "hint.x")
        XCTAssertEqual(SetupFailure.probeFailed(rejection).hint, rejection)
        XCTAssertEqual(SetupEngine.keychainFailure(KeychainFailure.status(-25_244)), .keychain(-25_244))
        XCTAssertEqual(SetupEngine.keychainFailure(FakeError.down), .keychain(-1))
    }

    func testEnginesDecideSyncOutcomesAndInputsAreTrimmed() async throws {
        XCTAssertEqual(SyncEngine.key("i", .files), "i|files")
        XCTAssertEqual(SyncEngine.kinds(of: .mail), [.mailboxes, .messages])
        XCTAssertEqual(SyncEngine.kinds(of: .files), [.files])
        XCTAssertTrue(SyncEngine.resolution(capability: .files, kind: .rejected) == .restore)
        XCTAssertTrue(SyncEngine.resolution(capability: .mail, kind: .transient) == .restore)
        XCTAssertTrue(SyncEngine.resolution(capability: .mail, kind: .signIn) == .fail)
        let classification = Classification(kind: .rejected, original: Original(provider: "p"))
        let expired = InletState.failed(Hint(text: Hint.signInExpiredText))
        XCTAssertEqual(SyncEngine.failureHint(for: classification, inlet: "i", current: expired).text, Hint.signInExpiredText)
        XCTAssertEqual(SyncEngine.failureHint(for: classification, inlet: "i", current: .working).text, "hint.provider.failed")
        XCTAssertEqual(SyncEngine.failureHint(for: classification, inlet: "i", current: nil).fixIn, .inlet("i"))
        let signIn = KeySignIn(ids: ["a", "b"])
        let grant = try await signIn.signIn(Inlet(id: "i", provider: "p", capabilities: [], owner: .company, title: "t"),
                                            input: ["a": " x\n", "b": "  ", "c": "ignored"])
        XCTAssertEqual(grant.values, ["a": "x"])
    }

    func testSmallValueTypesBehave() {
        let folder = FileFolder(id: "f", name: "n")
        let item = ProjectFolder(inlet: "i", folder: folder)
        XCTAssertEqual(item.id, "i/f")
        XCTAssertEqual(Mailbox(id: "m", inlet: "i", name: "Inbox", role: "inbox").inlet, "i")
        XCTAssertEqual(SyncOutcome(deliveries: [.files: [item], .mailboxes: [Mailbox(id: "m", inlet: "i", name: "n", role: "r")]]).count, 2)
        XCTAssertEqual(DataKind.projects.capability, nil)
        XCTAssertEqual(DataKind.receipts.capability, .documents)
        XCTAssertEqual(Set(DataKind.allCases.compactMap(\.capability)).isSubset(of: Set(Capability.allCases)), true)
        XCTAssertEqual(InletState.connected(probed: .distantPast).isConnected, true)
        XCTAssertEqual(InletState.created.canRenew, false)
        XCTAssertEqual(Input.none.values, [:])
        XCTAssertEqual(Input.fields(["a": "b"]).values, ["a": "b"])
    }

    func testLegacyImportCopiesOnceAndNeverTouchesTheOldData() throws {
        let folder = URL(fileURLWithPath: ProcessInfo.processInfo.environment["TMPDIR"] ?? NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("hub.sqlite")
        let inlet = Inlet(id: "g1", provider: "google", capabilities: [.mail], owner: .company, title: "T", account: "a@x")
        let entry = ReportEntry(inlet: "g1", event: .probe, at: Date(timeIntervalSince1970: 5), ok: true)
        let legacy = try DatabaseQueue(path: file.path)
        try legacy.write { db in
            try db.execute(sql: "CREATE TABLE inlet (id TEXT PRIMARY KEY, json BLOB NOT NULL)")
            try db.execute(sql: "CREATE TABLE key_slot (inlet TEXT NOT NULL, name TEXT NOT NULL, PRIMARY KEY (inlet, name))")
            try db.execute(sql: """
                CREATE TABLE inlet_report (
                    seq INTEGER PRIMARY KEY AUTOINCREMENT, inlet TEXT NOT NULL, at REAL NOT NULL, json BLOB NOT NULL)
                """)
            try db.execute(sql: "CREATE TABLE setting (key TEXT PRIMARY KEY, value BLOB NOT NULL)")
            try db.execute(sql: """
                CREATE TABLE cost_day (
                    inlet TEXT NOT NULL, capability TEXT NOT NULL, day INTEGER NOT NULL,
                    calls INTEGER NOT NULL DEFAULT 0, bytes INTEGER NOT NULL DEFAULT 0, tokens INTEGER NOT NULL DEFAULT 0,
                    PRIMARY KEY (inlet, capability, day))
                """)
            try db.execute(sql: "INSERT INTO inlet (id, json) VALUES ('g1', ?)", arguments: [try JSONEncoder().encode(inlet)])
            try db.execute(sql: "INSERT INTO inlet (id, json) VALUES ('bad', ?)", arguments: [Data("garbage".utf8)])
            try db.execute(sql: "INSERT INTO key_slot (inlet, name) VALUES ('g1', 'token'), ('gone', 'token')")
            try db.execute(sql: "INSERT INTO inlet_report (inlet, at, json) VALUES ('g1', 5, ?)", arguments: [try JSONEncoder().encode(entry)])
            try db.execute(sql: "INSERT INTO setting (key, value) VALUES ('cadence|g1|mail', ?)", arguments: [try JSONEncoder().encode(Cadence.manual)])
            try db.execute(sql: "INSERT INTO cost_day VALUES ('g1', 'mail', 20000, 3, 40, 5)")
        }
        let before = try Data(contentsOf: file)
        let suite = "legacy-import-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("dark", forKey: SettingsKey.appearance)
        defaults.set("settings", forKey: SettingsKey.startDestination)
        defaults.set(false, forKey: SettingsKey.lockOn)
        defaults.set("minute1", forKey: SettingsKey.lockDelay)
        defaults.set(true, forKey: SettingsKey.loadImages)
        defaults.set("Ada", forKey: SettingsKey.identityName)
        defaults.set(true, forKey: SettingsKey.birthdays)
        defaults.set("Firm", forKey: CompanyEntry.name.storageKey)
        defaults.set("nonsense", forKey: SettingsKey.lockDelay + "x")
        defaults.set(7, forKey: SettingsKey.assistantOff)
        let database = try SQLiteStore.inMemory()
        let store = LegacyImportStore(database: database, defaults: defaults, legacyFile: file)
        let first = try store.run()
        XCTAssertEqual(first.outcome, .partial)
        XCTAssertEqual([first.inlets, first.slots, first.reports, first.settings, first.costDays, first.preferences], [1, 1, 1, 1, 1, 8])
        XCTAssertEqual(Set(first.skipped), ["inlet:bad", "key_slot:gone", "default:" + SettingsKey.assistantOff])
        func snapshot() throws -> [String] {
            try database.read { db in
                try Row.fetchAll(db, sql: """
                    SELECT 'i:' || id || (json = json) FROM inlet UNION ALL SELECT 's:' || inlet || name FROM key_slot
                    UNION ALL SELECT 'r:' || inlet || at FROM inlet_report UNION ALL SELECT 'k:' || key || hex(value) FROM setting
                    UNION ALL SELECT 'c:' || inlet || day || calls FROM cost_day
                    """).map { $0[0] as String }.sorted()
            }
        }
        let stored = try snapshot()
        XCTAssertEqual(try InletStore(database: database).load().map(\.id), ["g1"])
        XCTAssertEqual(try InletStore(database: database).slots(of: "g1"), ["token"])
        let values = try SettingStore(database: database).all()
        XCTAssertEqual(SettingStore.decoded(values[SettingsKey.appearance], as: String.self), "dark")
        XCTAssertEqual(SettingStore.decoded(values[SettingsKey.lockOn], as: Bool.self), false)
        XCTAssertEqual(SettingStore.decoded(values[CompanyEntry.name.storageKey], as: String.self), "Firm")
        XCTAssertNil(values[SettingsKey.assistantOff])
        XCTAssertEqual(SettingStore.decoded(values[SettingsKey.legacyImportDone], as: LegacyImportResult.self), first)
        defaults.set("light", forKey: SettingsKey.appearance)
        try legacy.write { db in try db.execute(sql: "INSERT INTO key_slot (inlet, name) VALUES ('g1', 'extra')") }
        let again = try store.run()
        XCTAssertEqual(again, first)
        XCTAssertEqual(try snapshot(), stored)
        XCTAssertEqual(try Data(contentsOf: file).count, before.count)
    }

    func testLegacyImportWithoutOldFileMarksNoneAndMismatchedSchemaImportsWhatFits() throws {
        let folder = URL(fileURLWithPath: ProcessInfo.processInfo.environment["TMPDIR"] ?? NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let suite = "legacy-import-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let missing = folder.appendingPathComponent("missing.sqlite")
        let database = try SQLiteStore.inMemory()
        let none = try LegacyImportStore(database: database, defaults: defaults, legacyFile: missing).run()
        XCTAssertEqual(none.outcome, .none)
        XCTAssertFalse(FileManager.default.fileExists(atPath: missing.path))
        XCTAssertEqual(try LegacyImportStore(database: database, defaults: defaults, legacyFile: missing).run(), none)
        let garbage = folder.appendingPathComponent("garbage.sqlite")
        try Data("not a database at all, just bytes".utf8).write(to: garbage)
        let broken = try LegacyImportStore(database: try SQLiteStore.inMemory(), defaults: defaults, legacyFile: garbage).run()
        XCTAssertEqual(broken.outcome, .none)
        XCTAssertFalse(broken.skipped.isEmpty)
        let odd = folder.appendingPathComponent("odd.sqlite")
        let queue = try DatabaseQueue(path: odd.path)
        try queue.write { db in
            try db.execute(sql: "CREATE TABLE setting (key TEXT PRIMARY KEY, value BLOB NOT NULL)")
            try db.execute(sql: "INSERT INTO setting (key, value) VALUES ('limit|mail', ?)", arguments: [Data("5".utf8)])
            try db.execute(sql: "CREATE TABLE cost_day (inlet TEXT NOT NULL)")
        }
        let target = try SQLiteStore.inMemory()
        let partial = try LegacyImportStore(database: target, defaults: defaults, legacyFile: odd).run()
        XCTAssertEqual(partial.outcome, .partial)
        XCTAssertEqual(partial.settings, 1)
        XCTAssertEqual(Set(partial.skipped), ["table:inlet", "table:key_slot", "table:inlet_report", "table:cost_day"])
        XCTAssertNotNil(try SettingStore(database: target).all()["limit|mail"])
    }
}
