import class GRDB.DatabaseQueue
import Hub
@testable import Mail
import struct MykilosServices.MailFolder
import struct MykilosServices.MailMessagePage
import struct MykilosServices.MailMessageSummary
import enum MykilosServices.MailTransportError
import XCTest

@MainActor
final class CoreModelTests: XCTestCase {
    func testModelOverCoreShowsOfflineWhenTheNetworkDrops() async throws {
        let hub = HubDouble()
        let transport = hub.add("one")
        transport.folders = [MailFolder(id: "INBOX", name: "Inbox", role: .inbox)]
        transport.setPage("INBOX", MailMessagePage(messages: [MailMessageSummary(id: "m1", subject: "s", from: "a")]))
        let core = try MailCore(hub: hub, database: DatabaseQueue())
        let model = MailModel(engine: core)
        await model.start()
        XCTAssertEqual(model.listState, .loaded)
        transport.listError = MailTransportError.timeout
        await model.loadSelection()
        guard case .offline = model.listState else { return XCTFail("state \(model.listState)") }
    }

    func testSubjectWithLeadingBlankIsShownAsReceived() async throws {
        let hub = HubDouble()
        let transport = hub.add("one")
        transport.folders = [MailFolder(id: "INBOX", name: "Inbox", role: .inbox)]
        transport.setPage("INBOX", MailMessagePage(messages: [message("1", subject: "  Offer 4711")]))
        let model = MailModel(engine: try MailCore(hub: hub, database: DatabaseQueue()))
        await model.start()
        let subject = model.rows.first?.summary.subject
    }
}
