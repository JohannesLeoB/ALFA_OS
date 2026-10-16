import Foundation
import GRDB
import Hub
@testable import Mail
import struct MykilosServices.MailFolder
import struct MykilosServices.MailMessageSummary
import XCTest

private final class SetupKeychain: KeychainPort, @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [KeySlot: String] = [:]

    func put(_ value: String, at slot: KeySlot) throws { lock.withLock { entries[slot] = value } }
    func get(_ slot: KeySlot) throws -> String? { lock.withLock { entries[slot] } }
    func delete(_ slot: KeySlot) throws { lock.withLock { entries[slot] = nil } }
}

private final class SetupCadence: CadencePort, @unchecked Sendable {
    private let lock = NSLock()
    private var planned: [String: Cadence] = [:]
    let reports = AsyncStream<SyncReport> { _ in }

    func planned(_ inlet: Inlet.ID, _ capability: Capability) -> Cadence? {
        lock.withLock { planned[inlet + "|" + capability.rawValue] }
    }

    func attach(_ runner: @escaping SyncRunner) {}
    func plan(_ inlet: Inlet.ID, _ capability: Capability, _ cadence: Cadence) {
        lock.withLock { planned[inlet + "|" + capability.rawValue] = cadence }
    }
    func trigger(_ inlet: Inlet.ID, _ capability: Capability) async {}
}

private final class SetupCost: CostPort, @unchecked Sendable {
    func book(_ item: CostItem) {}
    func sum(_ inlet: Inlet.ID, _ period: Period) -> Cost { .zero }
}

private struct SetupSignIn: SignInPort {
    func signIn(_ inlet: Inlet, input: [Field.ID: String]) async throws -> Grant { Grant(values: ["token": inlet.id]) }
    func renew(_ grant: Grant) async throws -> Grant { grant }
    func signOut(_ inlet: Inlet) async throws {}
}

private final class SetupFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Bool

    init(_ value: Bool) { current = value }

    var value: Bool {
        get { lock.withLock { current } }
        set { lock.withLock { current = newValue } }
    }
}

private struct SetupProbe: ProbePort {
    let accepting: SetupFlag

    func probe(_ inlet: Inlet, _ grant: Grant) async throws -> ProbeResult {
        accepting.value ? ProbeResult(account: "a@x.test") : ProbeResult(account: "a@x.test", rejection: Hint(text: "hint.setup"))
    }
}

private struct SetupProvider: Provider {
    let id = "double"
    let capabilities: Set<Capability> = [.mail]
    let form: [Field] = []
    let presets: [Preset] = []
    let signIn: any SignInPort = SetupSignIn()
    let probe: any ProbePort

    init(accepting: SetupFlag = SetupFlag(true)) { probe = SetupProbe(accepting: accepting) }

    func adapter<P>(_ port: P.Type, for inlet: Inlet, _ grant: Grant, renewal: GrantRenewal) throws -> P {
        throw HubError.capabilityMissing(inlet.id, .mail)
    }
}

@MainActor
final class SetupTests: XCTestCase {
    private let person = Person(id: "p1", name: "P")

    private func directory(withGoogle: Bool) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("alfa-setup-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        if withGoogle {
            let json = #"{"clientID":"id.example","clientSecret":"secret"}"#
            try json.write(to: url.appendingPathComponent("google-client.json"), atomically: true, encoding: .utf8)
        }
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func assembly(withGoogle: Bool, cadence: SetupCadence = SetupCadence()) throws -> MailSetup.Assembly {
        try MailSetup.make(
            person: person, company: CompanySetup(), openBrowser: { _ in true },
            directory: try directory(withGoogle: withGoogle), database: try HubDatabase.inMemory(),
            keychain: SetupKeychain(), cadence: cadence, cost: SetupCost()
        )
    }

    private func assembled(accepting: SetupFlag, database: DatabaseQueue) throws -> MailSetup.Assembly {
        try MailSetup.assemble(
            person: person, company: CompanySetup(), providers: [SetupProvider(accepting: accepting)],
            database: database, keychain: SetupKeychain(), cadence: SetupCadence(), cost: SetupCost(),
            cadences: MailSetup.defaultCadences, clock: { Date() })
    }

    private func rows(_ database: DatabaseQueue, _ inlet: Inlet.ID) throws -> Int {
        try database.read { db in
            try Int.fetchOne(db, sql: "SELECT (SELECT COUNT(*) FROM mail_message WHERE inlet = ?) + (SELECT COUNT(*) FROM mail_folder WHERE inlet = ?)",
                             arguments: [inlet, inlet]) ?? 0
        }
    }

    func testOffersDependOnTheGoogleConfiguration() throws {
        let imapOnly = try assembly(withGoogle: false).hub.setup.offers
        XCTAssertFalse(imapOnly.isEmpty)
        XCTAssertEqual(Set(imapOnly.map(\.provider)), ["imap"])
        for offer in imapOnly {
            guard case .form(let fields) = offer.way else { return XCTFail("way \(offer.way)") }
            XCTAssertFalse(fields.isEmpty)
            XCTAssertEqual(offer.capabilities, [.mail])
            XCTAssertEqual(offer.owner, .person("p1"))
        }
        XCTAssertTrue(imapOnly.allSatisfy { $0.preset != nil })

        let withGoogle = try assembly(withGoogle: true).hub.setup.offers
        XCTAssertEqual(Set(withGoogle.map(\.provider)), ["google", "imap"])
        let google = withGoogle.filter { $0.provider == "google" }
        XCTAssertEqual(google.count, 1)
        XCTAssertEqual(google.first?.way, .signIn)
    }

    func testAssemblyIsUsableWithoutAnyInlet() throws {
        let result = try assembly(withGoogle: false)
        XCTAssertEqual(result.hub.setup.inlets, [])
        XCTAssertEqual(result.engine.accounts, [])
        XCTAssertEqual(result.model.accounts, [])
    }

    func testCadenceOfANewInletComesFromTheConfiguration() async throws {
        let cadence = SetupCadence()
        let result = try MailSetup.assemble(
            person: person, company: CompanySetup(), providers: [SetupProvider()],
            database: try HubDatabase.inMemory(), keychain: SetupKeychain(), cadence: cadence, cost: SetupCost(),
            cadences: MailSetup.defaultCadences, clock: { Date() }
        )
        let offer = try XCTUnwrap(result.hub.setup.offers.first)
        XCTAssertEqual(offer.way, .signIn)
        let inlet = try await result.hub.setup.add(offer)
        XCTAssertEqual(cadence.planned(inlet.id, .mail), .every(.seconds(300)))
        XCTAssertEqual(result.hub.rules.cadence(inlet.id, .mail), .every(.seconds(300)))

        let configuredCadence = SetupCadence()
        let configured = try MailSetup.assemble(
            person: person, company: CompanySetup(), providers: [SetupProvider()],
            database: try HubDatabase.inMemory(), keychain: SetupKeychain(), cadence: configuredCadence, cost: SetupCost(),
            cadences: [.mail: .seconds(60)], clock: { Date() }
        )
        let configuredInlet = try await configured.hub.setup.add(try XCTUnwrap(configured.hub.setup.offers.first))
        XCTAssertEqual(configuredCadence.planned(configuredInlet.id, .mail), .every(.seconds(60)))
    }

    func testRenewalKeepsTheCadenceTheUserSet() async throws {
        let accepting = SetupFlag(true)
        let result = try assembled(accepting: accepting, database: try HubDatabase.inMemory())
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
    }

    func testRemovedAccountTakesItsMirroredMailWithIt() async throws {
        let database = try HubDatabase.inMemory()
        let result = try assembled(accepting: SetupFlag(true), database: database)
        let inlet = try await result.hub.setup.add(try XCTUnwrap(result.hub.setup.offers.first))
        let mirror = try MailMirror(database)
        try mirror.replaceFolders(inlet.id, [MailFolder(id: "INBOX", name: "Inbox", role: .inbox)])
        try mirror.replaceMessages(inlet.id, folder: "INBOX", [MailMessageSummary(id: "m1", subject: "s", from: "a")], at: Date())
        try await result.hub.setup.remove(inlet.id)
        let left = try rows(database, inlet.id)
        XCTAssertEqual(left, 2)
    }
}
