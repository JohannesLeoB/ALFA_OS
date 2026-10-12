import Foundation
import GRDB
import Hub
@testable import Mail
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

private struct SetupProbe: ProbePort {
    func probe(_ inlet: Inlet, _ grant: Grant) async throws -> ProbeResult { ProbeResult(account: inlet.id) }
}

private struct SetupProvider: Provider {
    let id = "double"
    let capabilities: Set<Capability> = [.mail]
    let form: [Field] = []
    let presets: [Preset] = []
    let signIn: any SignInPort = SetupSignIn()
    let probe: any ProbePort = SetupProbe()

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

    func testWithoutGoogleConfigurationOnlyImapIsOffered() throws {
        let offers = try assembly(withGoogle: false).hub.setup.offers
        XCTAssertFalse(offers.isEmpty)
        XCTAssertEqual(Set(offers.map(\.provider)), ["imap"])
        for offer in offers {
            guard case .form(let fields) = offer.way else { return XCTFail("way \(offer.way)") }
            XCTAssertFalse(fields.isEmpty)
            XCTAssertEqual(offer.capabilities, [.mail])
            XCTAssertEqual(offer.owner, .person("p1"))
        }
        XCTAssertTrue(offers.allSatisfy { $0.preset != nil })
    }

    func testWithGoogleConfigurationGoogleAndImapAreOffered() throws {
        let offers = try assembly(withGoogle: true).hub.setup.offers
        XCTAssertEqual(Set(offers.map(\.provider)), ["google", "imap"])
        let google = offers.filter { $0.provider == "google" }
        XCTAssertEqual(google.count, 1)
        XCTAssertEqual(google.first?.way, .signIn)
    }

    func testAssemblyIsUsableWithoutAnyInlet() throws {
        let result = try assembly(withGoogle: false)
        XCTAssertEqual(result.hub.setup.inlets, [])
        XCTAssertEqual(result.engine.accounts, [])
        XCTAssertEqual(result.model.accounts, [])
    }

    func testNewMailInletGetsTheInboxCadence() async throws {
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
    }

    func testCadenceIntervalComesFromTheConfiguration() async throws {
        let cadence = SetupCadence()
        let result = try MailSetup.assemble(
            person: person, company: CompanySetup(), providers: [SetupProvider()],
            database: try HubDatabase.inMemory(), keychain: SetupKeychain(), cadence: cadence, cost: SetupCost(),
            cadences: [.mail: .seconds(60)], clock: { Date() }
        )
        let inlet = try await result.hub.setup.add(try XCTUnwrap(result.hub.setup.offers.first))
        XCTAssertEqual(cadence.planned(inlet.id, .mail), .every(.seconds(60)))
    }
}
