import Foundation
import GRDB
import Hub
import struct MykilosServices.IMAPSMTPMailTransport
import protocol MykilosServices.MailTransport
import enum MykilosServices.MailTransportError
import struct MykilosServices.MailProbeError
import XCTest

@MainActor
final class IMAPProviderTests: XCTestCase {
    static let gmx: [Field.ID: String] = [
        "address": "jo@gmx.example",
        "incomingHost": "imap.gmx.net",
        "incomingPort": "993",
        "incomingSecurity": "ssl",
        "outgoingHost": "mail.gmx.net",
        "outgoingPort": "587",
        "outgoingSecurity": "starttls",
        "username": "jo@gmx.example",
        "password": "app-secret"
    ]

    static let offer = Offer(id: "imap.mail", provider: IMAPProvider.providerID, title: "GMX", capabilities: [.mail],
                             owner: .person("p1"), way: .form([]))

    private func probe(_ provider: IMAPProvider, values: [Field.ID: String] = IMAPProviderTests.gmx) async throws -> ProbeResult {
        let inlet = Inlet(id: "imap-1", provider: provider.id, capabilities: [.mail], owner: .person("p1"), title: "GMX")
        let grant = try await provider.signIn.signIn(inlet, input: values)
        return try await provider.probe.probe(inlet, grant)
    }

    func testPresetGMXFillsServerAndPorts() throws {
        let gmx = try XCTUnwrap(IMAPProvider().presets.first { $0.id == "gmx" })
        XCTAssertEqual(gmx.values["incomingHost"], "imap.gmx.net")
        XCTAssertEqual(gmx.values["incomingPort"], "993")
        XCTAssertEqual(gmx.values["incomingSecurity"], "ssl")
        XCTAssertEqual(gmx.values["outgoingHost"], "mail.gmx.net")
        XCTAssertEqual(gmx.values["outgoingPort"], "587")
        XCTAssertEqual(gmx.values["outgoingSecurity"], "starttls")
    }

    func testPresetsWithoutGmailAndOutlook() throws {
        let provider = IMAPProvider()
        XCTAssertEqual(provider.presets.map(\.id), ["ionos", "gmx", "webde", "icloud", "fastmail", "generic"])
        XCTAssertFalse(provider.presets.contains { $0.id == "gmail" || $0.id == "outlook" })
        let ionos = try XCTUnwrap(provider.presets.first { $0.id == "ionos" })
        XCTAssertEqual(ionos.values["incomingHost"], "imap.ionos.de")
        XCTAssertEqual(ionos.values["outgoingHost"], "smtp.ionos.de")
        XCTAssertEqual(ionos.values["outgoingPort"], "465")
        let fastmail = try XCTUnwrap(provider.presets.first { $0.id == "fastmail" })
        XCTAssertEqual(fastmail.values["incomingHost"], "imap.fastmail.com")
        XCTAssertEqual(fastmail.values["outgoingHost"], "smtp.fastmail.com")
        XCTAssertEqual(provider.presets.last?.values["incomingHost"], nil)
        let ids = Set(provider.form.map(\.id))
        for preset in provider.presets { XCTAssertTrue(Set(preset.values.keys).isSubset(of: ids), preset.id) }
        XCTAssertEqual(provider.form.filter(\.secret).map(\.id), ["password"])
        XCTAssertEqual(provider.capabilities, [.mail])
    }

    func testSignInRejectsNone() async throws {
        let provider = IMAPProvider()
        let inlet = Inlet(id: "i", provider: provider.id, capabilities: [.mail], owner: .company, title: "t")
        for field in ["incomingSecurity", "outgoingSecurity"] {
            var values = Self.gmx
            values[field] = "none"
            do {
                _ = try await provider.signIn.signIn(inlet, input: values)
                XCTFail("plain connection must throw")
            } catch let error as IMAPSetupError {
                XCTAssertEqual(error, .insecure(field: field))
            }
        }
    }

    func testSignInChecksPasswordAndPortAndKeepsThePasswordInTheGrant() async throws {
        let provider = IMAPProvider()
        let inlet = Inlet(id: "i", provider: provider.id, capabilities: [.mail], owner: .company, title: "t")
        var values = Self.gmx
        values["password"] = ""
        do {
            _ = try await provider.signIn.signIn(inlet, input: values)
            XCTFail("empty password must throw")
        } catch let error as IMAPSetupError {
            XCTAssertEqual(error, .missing("password"))
        }
        values = Self.gmx
        values["incomingPort"] = "99999"
        do {
            _ = try await provider.signIn.signIn(inlet, input: values)
            XCTFail("bad port must throw")
        } catch let error as IMAPSetupError {
            XCTAssertEqual(error, .invalidPort(field: "incomingPort", value: "99999"))
        }
        let grant = try await provider.signIn.signIn(inlet, input: Self.gmx)
        XCTAssertEqual(grant.values["password"], "app-secret")
        XCTAssertEqual(grant.values["outgoingSecurity"], "starttls")
    }

    func testProbeIsGreenWhenTheRunSucceedsAndHandsOverTheAccount() async throws {
        let seen = Locked<[String]>([])
        let provider = IMAPProvider(probeRun: { account, password in
            seen.with { $0 = [account.incoming.host, account.outgoing.host, account.address, password] }
        })
        let result = try await probe(provider)
        XCTAssertTrue(result.accepted)
        XCTAssertEqual(result.account, "jo@gmx.example")
        XCTAssertEqual(seen.with { $0 }, ["imap.gmx.net", "mail.gmx.net", "jo@gmx.example", "app-secret"])
    }

    func testProbeNamesTheServerAnswerOfTheFailedStep() async throws {
        let login = IMAPProvider(probeRun: { _, _ in
            throw MailProbeError(step: .incoming, reason: .authenticationRejected("NO Invalid credentials"))
        })
        let first = try await probe(login).rejection
        XCTAssertEqual(first, Hint(text: "hint.imap.login.rejected", detail: "NO Invalid credentials", fixIn: .inlet("imap-1")))
        let auth = IMAPProvider(probeRun: { _, _ in
            throw MailProbeError(step: .outgoing, reason: .authenticationRejected("535 Authentication credentials invalid"))
        })
        let second = try await probe(auth).rejection
        XCTAssertEqual(second?.text, "hint.smtp.auth.rejected")
        XCTAssertEqual(second?.detail, "535 Authentication credentials invalid")
        let timeout = IMAPProvider(probeRun: { _, _ in throw MailProbeError(step: .incoming, reason: .timeout) })
        let third = try await probe(timeout).rejection
        XCTAssertEqual(third?.text, "hint.imap.connection.timeout")
        let other = IMAPProvider(probeRun: { _, _ in throw URLError(.cannotFindHost) })
        let fourth = try await probe(other).rejection
        XCTAssertEqual(fourth?.text, "hint.imap.failed")
    }

    func testAdapterDeliversAMailTransportWithoutTouchingTheNetwork() throws {
        let provider = IMAPProvider()
        let inlet = Inlet(id: "i", provider: provider.id, capabilities: [.mail], owner: .company, title: "t")
        let grant = Grant(values: Self.gmx)
        _ = try provider.adapter(MailTransport.self, for: inlet, grant, renewal: .ignoring) as any MailTransport
        XCTAssertThrowsError(try provider.adapter((any CalendarPort).self, for: inlet, grant, renewal: .ignoring)) {
            XCTAssertEqual($0 as? HubError, .capabilityMissing(inlet.id, .mail))
        }
    }

    private func rig(keychain: FakeKeychain, run: @escaping IMAPProbeRun) throws -> Hub {
        let configuration = HubConfiguration(
            person: Person(id: "p1", name: "P"), company: CompanySetup(offers: [Self.offer]),
            providers: [IMAPProvider(probeRun: run)], keychain: keychain, cadence: HandCadence(), cost: FakeCost(),
            catalog: .withMail, database: try DatabaseQueue())
        return try Hub.make(configuration)
    }

    func testHubStoresThePasswordInTheKeychainAfterAGreenProbe() async throws {
        let keychain = FakeKeychain()
        let hub = try rig(keychain: keychain, run: { _, _ in })
        let inlet = try await hub.setup.add(Self.offer, input: .fields(Self.gmx))
        guard case .connected = inlet.state else { return XCTFail("state \(inlet.state)") }
        XCTAssertEqual(try keychain.get(KeySlot(inlet: inlet.id, name: "password")), "app-secret")
        _ = try hub.access.port(MailTransport.self, for: inlet.id)
    }

    func testHubKeepsNothingAfterARedProbe() async throws {
        let keychain = FakeKeychain()
        let hub = try rig(keychain: keychain, run: { _, _ in
            throw MailProbeError(step: .incoming, reason: .authenticationRejected("NO x"))
        })
        do {
            _ = try await hub.setup.add(Self.offer, input: .fields(Self.gmx))
            XCTFail("add must throw")
        } catch SetupError.probeFailed(let hint) {
            XCTAssertEqual(hint.text, "hint.imap.login.rejected")
        }
        XCTAssertEqual(hub.setup.inlets, [])
        XCTAssertTrue(keychain.slots.isEmpty)
    }

    /// Der Absendername kommt aus dem Formularwert "name", nicht aus dem Angebotstitel ("GMX") und nie leer.
    func testSenderNameOfTheTransportIsTheFormValue() async throws {
        var values = Self.gmx
        values["name"] = "Jo Berger"
        var catalog = PortCatalog.standard
        catalog.register((any MailTransport).self, capability: .mail)
        let hub = try Hub.make(HubConfiguration(
            person: Person(id: "p1", name: "P"), company: CompanySetup(offers: [Self.offer]),
            providers: [IMAPProvider(probeRun: { _, _ in })], keychain: FakeKeychain(), cadence: HandCadence(),
            cost: FakeCost(), catalog: catalog, database: try DatabaseQueue()))
        let inlet = try await hub.setup.add(Self.offer, input: .fields(values))
        let transport = try hub.access.port((any MailTransport).self, for: inlet.id)
        let name = (transport as? IMAPSMTPMailTransport)?.account.displayName
        XCTAssertEqual(name, "Jo Berger")
    }

    func testAddressWithInnerSpaceIsRejected() {
        var input = Self.gmx
        input["address"] = "jo @gmx.example"
        let rejected = (try? IMAPConnection(values: input)) == nil
        XCTExpectFailure("BUG-3-24: IMAPConnection only checks for an @ that is not first or last") {
            XCTAssertTrue(rejected)
        }
    }
}
