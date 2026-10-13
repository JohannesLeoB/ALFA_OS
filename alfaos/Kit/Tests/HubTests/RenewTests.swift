import Foundation
import GRDB
import Hub
import protocol MykilosServices.MailTransport
import XCTest

@MainActor
final class RenewTests: XCTestCase {
    struct Rig {
        let hub: Hub
        let provider: FakeProvider
        let keychain: FakeKeychain
    }

    static let mailOffer = Offer(id: "fake.mail", provider: "fake", title: "Mail", capabilities: [.mail],
                                 owner: .person("p1"), way: .signIn)

    func rig(capabilities: Set<Capability>) throws -> Rig {
        let provider = FakeProvider(capabilities: capabilities)
        let keychain = FakeKeychain()
        let configuration = HubConfiguration(
            person: Person(id: "p1", name: "P"), company: CompanySetup(offers: [Self.mailOffer]), providers: [provider],
            keychain: keychain, cadence: HandCadence(), cost: FakeCost(), catalog: .withMail,
            database: try DatabaseQueue()
        )
        return Rig(hub: try Hub.make(configuration), provider: provider, keychain: keychain)
    }

    func connect(_ rig: Rig, _ address: String) async throws -> Inlet {
        try await rig.hub.setup.add(Self.mailOffer, input: .fields(["address": address]))
    }

    func testFailedInletIsRenewedInPlace() async throws {
        let rig = try rig(capabilities: [.mail])
        let first = try await connect(rig, "a@x")
        rig.provider.setAccepting(false)
        do {
            _ = try await rig.hub.setup.probe(first.id)
            XCTFail("probe must throw")
        } catch SetupError.probeFailed {
        }
        XCTAssertTrue(rig.hub.setup.inlets[0].state.canRenew)
        XCTAssertEqual(rig.hub.setup.renewal(of: first.id)?.offer, Self.mailOffer)
        rig.provider.setAccepting(true)
        let renewed = try await connect(rig, "a@x")
        XCTAssertEqual(renewed.id, first.id)
        XCTAssertEqual(rig.hub.setup.inlets.map(\.id), [first.id])
        XCTAssertNotNil(rig.hub.setup.inlets[0].state.probed)
        XCTAssertEqual(rig.keychain.slots.map(\.inlet), [first.id])
        XCTAssertNil(rig.hub.setup.renewal(of: first.id))
        _ = try rig.hub.access.port(MailTransport.self, for: first.id)
    }

    func testConnectedInletStillRefusesTheSameAccount() async throws {
        let rig = try rig(capabilities: [.mail])
        _ = try await connect(rig, "a@x")
        do {
            _ = try await connect(rig, "a@x")
            XCTFail("add must throw")
        } catch {
            XCTAssertEqual(error as? SetupError, .duplicate)
        }
        XCTAssertEqual(rig.hub.setup.inlets.count, 1)

        let caseRig = try self.rig(capabilities: [.mail])
        _ = try await connect(caseRig, "A@x")
        var second: Inlet?
        do { second = try await connect(caseRig, "a@x") } catch {}
        XCTExpectFailure("BUG-3-11: duplicate check compares account strings exactly and ignores the owner") {
            XCTAssertNil(second)
        }
        XCTExpectFailure("BUG-3-11: duplicate check compares account strings exactly and ignores the owner") {
            XCTAssertEqual(caseRig.hub.setup.inlets.count, 1)
        }
    }
}
