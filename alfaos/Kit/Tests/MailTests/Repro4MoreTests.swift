import class GRDB.DatabaseQueue
import Hub
@testable import Mail
import struct MykilosKit.EmailDraft
import enum MykilosServices.MailTransportError
import XCTest

@MainActor
final class Repro4MoreTests: XCTestCase {
    func testOutboxDraftLosesItsHtmlBodyInTheDatabase() async throws {
        let hub = Repro4Hub()
        let transport = hub.add("one")
        transport.sendError = MailTransportError.timeout
        let database = try DatabaseQueue()
        let first = try MailCore(hub: hub, database: database)
        let html = EmailDraft(to: "z@example.test", subject: "s", body: "plain", bodyHTML: "<b>formatted</b>")
        _ = await first.send("one", html)
        XCTAssertEqual(first.outbox.first?.draft.bodyHTML, "<b>formatted</b>")
        let second = try MailCore(hub: hub, database: database)
        let restored = second.outbox.first?.draft.bodyHTML
        XCTExpectFailure("BUG-4-25: EmailDraft encodes without bodyHTML, so a queued formatted mail is sent as plain text after a restart") {
            XCTAssertEqual(restored, "<b>formatted</b>")
        }
    }

    func testAccountAddedLaterIsNotSelectedWhenNothingIsSelected() async {
        let engine = Repro4Engine()
        let model = MailModel(engine: engine)
        await model.start()
        XCTAssertNil(model.selectedInlet)
        engine.accounts = [fakeAccount("a")]
        engine.folderList["a"] = repro4Inbox
        await model.handle(.accountsChanged)
        XCTAssertEqual(model.accounts.map(\.id), ["a"])
        XCTExpectFailure("BUG-4-26: refreshAccounts only repairs a selection that vanished, an account that appears while nothing is selected stays unselected and its list never loads") {
            XCTAssertEqual(model.selectedInlet, "a")
        }
    }
}
