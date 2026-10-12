import class GRDB.DatabaseQueue
import Hub
@testable import Mail
import struct MykilosServices.MailFolder
import struct MykilosServices.MailMessagePage
import XCTest

@MainActor
final class Repro4TextTests: XCTestCase {
    func testReplySetsInReplyToToTheProviderIdNotTheMessageIdHeader() async throws {
        let engine = ModelFakeEngine()
        engine.accounts = [fakeAccount("a")]
        engine.folderList["a"] = [MailFolder(id: "INBOX", name: "Inbox", role: .inbox)]
        engine.pages[nil] = MailMessagePage(messages: [fakeMessage("18f3a9c0de12", thread: "18f3a9c0de00")])
        let model = MailModel(engine: engine)
        await model.start()
        let made = await model.reply(to: "18f3a9c0de12")
        let id = try XCTUnwrap(made)
        let reference = model.draft(id)?.draft.inReplyTo
        XCTAssertEqual(reference, "18f3a9c0de12")
        XCTExpectFailure("BUG-4-14: inReplyTo is the provider id of the message, MailMessageSummary carries no Message-ID header, so In-Reply-To in the sent mail is not a valid message id") {
            XCTAssertTrue(reference?.contains("@") == true, "reference \(String(describing: reference))")
        }
    }

    func testSubjectWithLeadingBlankIsShownAsReceived() async throws {
        let hub = HubDouble()
        let transport = hub.add("one")
        transport.folders = [MailFolder(id: "INBOX", name: "Inbox", role: .inbox)]
        transport.setPage("INBOX", MailMessagePage(messages: [message("1", subject: "  Offer 4711")]))
        let model = MailModel(engine: try MailCore(hub: hub, database: DatabaseQueue()))
        await model.start()
        let subject = model.rows.first?.summary.subject
        XCTExpectFailure("BUG-4-15: neither transport, mirror nor model trims the subject, a leading blank reaches the row") {
            XCTAssertEqual(subject, "Offer 4711")
        }
    }

    func testOpeningAMailWhoseBodyFailsStillMarksItRead() async throws {
        let engine = Repro4Engine()
        engine.accounts = [fakeAccount("a")]
        engine.folderList["a"] = repro4Inbox
        engine.pages[Repro4Engine.key("a", "INBOX", nil)] = MailMessagePage(messages: [fakeMessage("m1")])
        engine.bodyError = .provider(Hint(text: MailHintKey.offline))
        let model = MailModel(engine: engine)
        await model.start()
        await model.open("m1")
        let failure = model.actionFailure(for: "m1")
        let calls = engine.flagCalls
        XCTExpectFailure("BUG-4-16: open marks the mail read although its body could not be loaded, and the successful flag call then erases the body failure hint") {
            XCTAssertEqual(calls, [])
            XCTAssertNotNil(failure)
        }
    }

    func testPlainTextKeepsNoBlockBreaks() {
        let paragraphs = MailText.plain("<p>Hello</p><p>World</p>")
        let lineBreak = MailText.plain("Hello<br>World")
        XCTExpectFailure("BUG-4-17: MailText.plain removes every tag, so paragraphs and line breaks run together") {
            XCTAssertEqual(paragraphs, "Hello\nWorld")
            XCTAssertEqual(lineBreak, "Hello\nWorld")
        }
    }

    func testPlainTextLeaksTitleAndConditionalComments() {
        let title = MailText.plain("<html><head><title>Page title</title></head><body>Body</body></html>")
        let conditional = MailText.plain("<!--[if mso]><p>Only Outlook</p><![endif]--><p>Real</p>")
        XCTExpectFailure("BUG-4-18: head, title and conditional comments are not removed, their text appears in the body") {
            XCTAssertEqual(title, "Body")
            XCTAssertEqual(conditional, "Real")
        }
    }

    func testPlainTextKeepsEntitiesOutsideItsTable() {
        let accent = MailText.plain("Caf&eacute;")
        let bullet = MailText.plain("a&bull;b")
        let trademark = MailText.plain("Pro&trade;")
        XCTAssertEqual(MailText.plain("Tom &amp; Jerry &#39;x&#39; &auml;"), "Tom & Jerry 'x' ä")
        XCTExpectFailure("BUG-4-19: only 26 named entities are known, the rest stays raw") {
            XCTAssertEqual(accent, "Café")
            XCTAssertEqual(bullet, "a•b")
            XCTAssertEqual(trademark, "Pro™")
        }
    }

    func testPlainTextKeepsTheIndentOfTheHtmlSource() {
        let text = MailText.plain("\n    <div>\n      <p>Hi</p>\n    </div>\n")
        XCTExpectFailure("BUG-4-20: plain does not trim or collapse source whitespace, the text starts with blank lines and an indent") {
            XCTAssertEqual(text, "Hi")
        }
    }
}
