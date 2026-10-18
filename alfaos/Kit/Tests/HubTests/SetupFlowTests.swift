import Foundation
import GRDB
import Hub
import struct AlfaServices.MailProbeError
import protocol AlfaServices.MailTransport
import XCTest

@MainActor
final class SetupFlowTests: XCTestCase {
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

    func testCancelDuringTheProbe() async throws {
        let stuck = try makeHub(run: { _, _ in try await Task.sleep(for: .seconds(3600)) })
        let addTask = Task { @MainActor () -> SetupError? in
            do {
                _ = try await stuck.setup.add(Self.offer, input: .fields(values()))
                return nil
            } catch {
                return error as? SetupError
            }
        }
        try await Task.sleep(for: .milliseconds(300))
        addTask.cancel()
        let addError = await addTask.value
        XCTAssertEqual(addError, .cancelled)

        let calls = Locked(0)
        let hub = try makeHub(run: { _, _ in
            let number = calls.with { (count: inout Int) -> Int in
                count += 1
                return count
            }
            if number > 1 { try await Task.sleep(for: .seconds(3600)) }
        })
        let inlet = try await hub.setup.add(Self.offer, input: .fields(values()))
        let probeTask = Task { @MainActor in _ = try? await hub.setup.probe(inlet.id) }
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(hub.setup.inlets.first?.state, .connecting)
        probeTask.cancel()
        await probeTask.value
        XCTAssertEqual(hub.setup.inlets.first?.state.canRenew, true)
    }

    func testInletOfAMissingProvider() async throws {
        let database = try DatabaseQueue()
        let keychain = FakeKeychain()
        let accepting = Locked(true)
        let first = try makeHub(keychain: keychain, database: database, run: { _, _ in
            if !accepting.with({ $0 }) { throw MailProbeError(step: .incoming, reason: .authenticationRejected("NO")) }
        })
        let connected = try await first.setup.add(Self.offer, input: .fields(values("jo@gmx.example")))
        let failedOne = try await first.setup.add(Self.offer, input: .fields(values("ka@gmx.example")))
        accepting.with { $0 = false }
        _ = try? await first.setup.probe(failedOne.id)
        accepting.with { $0 = true }
        let restarted = try makeHub(keychain: keychain, database: database, providers: [], offers: [])
        XCTAssertEqual(restarted.setup.inlets.first { $0.id == failedOne.id }?.state.canRenew, true)
        XCTAssertThrowsError(try restarted.access.port((any MailTransport).self, for: connected.id))
        XCTAssertEqual(restarted.setup.inlets.count, 2)
    }

    func testOneCorruptSettingRowStopsTheWholeHub() throws {
        let limitDatabase = try DatabaseQueue()
        _ = try makeHub(database: limitDatabase)
        try limitDatabase.write { db in
            try db.execute(sql: "INSERT INTO setting (key, value) VALUES ('limit|mail', ?)", arguments: [Data("x".utf8)])
        }
        let cadenceDatabase = try DatabaseQueue()
        _ = try makeHub(database: cadenceDatabase)
        try cadenceDatabase.write { db in
            try db.execute(sql: "INSERT INTO setting (key, value) VALUES ('cadence|x|mail', ?)", arguments: [Data("garbage".utf8)])
        }
    }

}
