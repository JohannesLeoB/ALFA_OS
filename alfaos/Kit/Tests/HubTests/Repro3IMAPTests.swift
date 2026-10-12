import Foundation
import GRDB
import Hub
import struct MykilosServices.IMAPSMTPMailTransport
import protocol MykilosServices.MailTransport
import XCTest

@MainActor
final class Repro3IMAPTests: XCTestCase {
    private let values: [Field.ID: String] = [
        "address": "jo@gmx.example", "incomingHost": "imap.gmx.net", "incomingPort": "993",
        "incomingSecurity": "ssl", "outgoingHost": "mail.gmx.net", "outgoingPort": "587",
        "outgoingSecurity": "starttls", "username": "jo@gmx.example", "password": "app-secret"
    ]

    func testBug22OfferTitleBecomesTheSenderName() async throws {
        let offer = Offer(id: "imap.gmx", provider: IMAPProvider.providerID, title: "GMX", capabilities: [.mail],
                          owner: .person("p1"), way: .form([]))
        var catalog = PortCatalog.standard
        catalog.register((any MailTransport).self, capability: .mail)
        let hub = try repro3Hub(providers: [IMAPProvider(probeRun: { _, _ in })], offer: offer,
                                keychain: FakeKeychain(), cadence: HandCadence(), database: try DatabaseQueue(),
                                catalog: catalog)
        let inlet = try await hub.setup.add(offer, input: .fields(values))
        let transport = try hub.access.port((any MailTransport).self, for: inlet.id)
        let name = (transport as? IMAPSMTPMailTransport)?.account.displayName
        XCTAssertNotNil(name)
        XCTAssertNotEqual(name, "GMX")
    }

    func testBug23PresetCountDiffersFromTheSevenTheReportsName() {
        let count = IMAPProvider().presets.count
        XCTExpectFailure("BUG-3-23: plan line A4 and the report say seven templates, the code has six (assertion pinned in IMAPProviderTests)") {
            XCTAssertEqual(count, 7)
        }
    }

    func testBug24AddressWithInnerSpaceIsAccepted() {
        var input = values
        input["address"] = "jo @gmx.example"
        let rejected = (try? IMAPConnection(values: input)) == nil
        XCTExpectFailure("BUG-3-24: IMAPConnection only checks for an @ that is not first or last") {
            XCTAssertTrue(rejected)
        }
    }
}
