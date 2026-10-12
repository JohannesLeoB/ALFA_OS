import Foundation
import GRDB
import Hub
import struct MykilosKit.EmailDraft
import protocol MykilosServices.MailTransport
import XCTest

@MainActor
final class HubTests: XCTestCase {
    struct Rig {
        let hub: Hub
        let provider: FakeProvider
        let keychain: FakeKeychain
        let cadence: HandCadence
        let cost: FakeCost
        let person: Person
    }

    static let mailOffer = Offer(id: "fake.mail", provider: "fake", title: "Mail", capabilities: [.mail],
                                 owner: .person("p1"), way: .signIn)

    func rig(capabilities: Set<Capability> = [.mail, .calendar], company: CompanySetup? = nil) throws -> Rig {
        let provider = FakeProvider(capabilities: capabilities)
        let keychain = FakeKeychain()
        let cadence = HandCadence()
        let cost = FakeCost()
        let person = Person(id: "p1", name: "P")
        let setup = company ?? CompanySetup(offers: [Self.mailOffer])
        let configuration = HubConfiguration(
            person: person, company: setup, providers: [provider], keychain: keychain, cadence: cadence,
            cost: cost, catalog: .withMail, database: try DatabaseQueue()
        )
        return Rig(hub: try Hub.make(configuration), provider: provider, keychain: keychain, cadence: cadence,
                   cost: cost, person: person)
    }

    func connect(_ rig: Rig, _ address: String) async throws -> Inlet {
        try await rig.hub.setup.add(Self.mailOffer, input: .fields(["address": address]))
    }

    func testStartsEmptyAndNothingThrows() throws {
        let rig = try rig()
        XCTAssertEqual(rig.hub.setup.inlets, [])
        let stock = rig.hub.access.stock(.mailboxes, as: MailboxRecord.self)
        XCTAssertEqual(stock.items, [])
        XCTAssertEqual(stock.state, .empty)
        XCTAssertEqual(rig.hub.access.inlets(for: .mail), [])
        XCTAssertTrue(rig.keychain.slots.isEmpty)
    }

    func testRejectedProbeLeavesNothingBehind() async throws {
        let rig = try rig()
        rig.provider.setAccepting(false)
        do {
            _ = try await connect(rig, "a@x")
            XCTFail("add must throw")
        } catch SetupError.probeFailed {
        }
        XCTAssertEqual(rig.hub.setup.inlets, [])
        XCTAssertTrue(rig.keychain.slots.isEmpty)
    }

    func testAcceptedProbeConnectsAndPortsFollowCapabilities() async throws {
        let rig = try rig(capabilities: [.mail])
        let inlet = try await connect(rig, "a@x")
        guard case .connected = inlet.state else { return XCTFail("state \(inlet.state)") }
        XCTAssertEqual(rig.hub.setup.inlets.map(\.id), [inlet.id])
        let transport = try rig.hub.access.port(MailTransport.self, for: inlet.id)
        let folders = try await transport.listFolders()
        XCTAssertEqual(folders.map(\.id), ["INBOX"])
        XCTAssertEqual(rig.provider.mail.listFoldersCalls, 1)
        XCTAssertThrowsError(try rig.hub.access.port(CalendarPort.self, for: inlet.id)) {
            XCTAssertEqual($0 as? HubError, .capabilityMissing(inlet.id, .calendar))
        }
    }

    func testFourthMailAccountNeedsALargerLimit() async throws {
        let rig = try rig()
        for address in ["a@x", "b@x", "c@x"] { _ = try await connect(rig, address) }
        do {
            _ = try await connect(rig, "d@x")
            XCTFail("add must throw")
        } catch {
            XCTAssertEqual(error as? SetupError, .limitReached(.mail, max: 3))
        }
        XCTAssertEqual(rig.hub.setup.inlets.count, 3)
        rig.hub.rules.setLimit(.mail, 5)
        _ = try await connect(rig, "d@x")
        XCTAssertEqual(rig.hub.setup.inlets.count, 4)
    }

    func testCadenceRunsOnePairOnceAndCountsTheCall() async throws {
        let rig = try rig()
        let inlet = try await connect(rig, "a@x")
        rig.hub.rules.setCadence(inlet.id, .mail, .every(.seconds(300)))
        XCTAssertEqual(rig.cadence.planned(inlet.id, .mail), .every(.seconds(300)))
        let gate = Gate()
        rig.provider.mail.setGate(gate)
        let first = Task { @MainActor in await rig.cadence.trigger(inlet.id, .mail) }
        for _ in 0..<400 where rig.provider.mail.listFoldersCalls == 0 { try await Task.sleep(for: .milliseconds(5)) }
        XCTAssertEqual(rig.provider.mail.listFoldersCalls, 1)
        await rig.cadence.trigger(inlet.id, .mail)
        await gate.release()
        await first.value
        XCTAssertEqual(rig.provider.mail.listFoldersCalls, 1)
        XCTAssertEqual(rig.hub.rules.cost(inlet.id, .all).calls, 1)
        let stock = rig.hub.access.stock(.mailboxes, as: MailboxRecord.self)
        XCTAssertEqual(stock.items.map(\.name), ["Inbox"])
        guard case .connected = rig.hub.setup.inlets[0].state else { return XCTFail("state") }
    }

    func testTeamWithoutSendRightCannotSend() async throws {
        let team = Right.all.subtracting([.sendMail, .manageInlets])
        let company = CompanySetup(offers: [Self.mailOffer], rights: [.admin: Right.all, .team: team])
        let rig = try rig(company: company)
        let inlet = try await connect(rig, "a@x")
        rig.hub.rules.setRole(rig.person.id, .team)
        do {
            try await rig.hub.access.write(.sendMail(inlet: inlet.id, draft: EmailDraft(to: "z@x", subject: "s", body: "b")))
            XCTFail("write must throw")
        } catch {
            XCTAssertEqual(error, .noRight(.sendMail))
        }
        XCTAssertEqual(rig.provider.mail.sent.count, 0)
        rig.hub.rules.setRole(rig.person.id, .admin)
        try await rig.hub.access.write(.sendMail(inlet: inlet.id, draft: EmailDraft(to: "z@x", subject: "s", body: "b")))
        XCTAssertEqual(rig.provider.mail.sent.count, 1)
    }

    func testSendRightWorksWithoutReadRight() async throws {
        let company = CompanySetup(offers: [Self.mailOffer], rights: [.admin: Right.all, .team: [.sendMail]])
        let rig = try rig(company: company)
        let inlet = try await connect(rig, "a@x")
        rig.hub.rules.setRole(rig.person.id, .team)
        try await rig.hub.access.write(.sendMail(inlet: inlet.id, draft: EmailDraft(to: "z@x", subject: "s", body: "b")))
        XCTAssertEqual(rig.provider.mail.sent.count, 1)
        XCTAssertThrowsError(try rig.hub.access.port(MailTransport.self, for: inlet.id)) {
            XCTAssertEqual($0 as? HubError, .noRight(.read(.mail)))
        }
    }

    func testRemoveKeepsTheKeysOfTheOtherInlet() async throws {
        let rig = try rig()
        let a = try await connect(rig, "a@x")
        let b = try await connect(rig, "b@x")
        XCTAssertEqual(Set(rig.keychain.slots.map(\.inlet)), [a.id, b.id])
        try await rig.hub.setup.remove(a.id)
        XCTAssertEqual(rig.keychain.slots.map(\.inlet), [b.id])
        XCTAssertEqual(rig.hub.setup.inlets.map(\.id), [b.id])
        _ = try rig.hub.access.port(MailTransport.self, for: b.id)
    }
}
