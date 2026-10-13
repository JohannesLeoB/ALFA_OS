import Mail
import XCTest

final class ModelTextTests: XCTestCase {
    func testPlainTextDropsScriptStyleAndTags() {
        let html = "<style>p{color:red}</style><p>Hallo <b>Welt</b></p><script>alert(1)</script>"
        XCTAssertEqual(MailText.plain(html), "Hallo Welt")
        let title = MailText.plain("<html><head><title>Page title</title></head><body>Body</body></html>")
        XCTExpectFailure("BUG-4-18: head, title and conditional comments are not removed, their text appears in the body") {
            XCTAssertEqual(title, "Body")
        }
        let conditional = MailText.plain("<!--[if mso]><p>Only Outlook</p><![endif]--><p>Real</p>")
        XCTExpectFailure("BUG-4-18: head, title and conditional comments are not removed, their text appears in the body") {
            XCTAssertEqual(conditional, "Real")
        }
    }

    func testPlainTextDecodesEntities() {
        XCTAssertEqual(MailText.plain("&quot;Volkswagen&quot; &amp; Co&nbsp;KG &#39;x&#x27; &auml; &unknown; AT&T"),
                       "\"Volkswagen\" & Co\u{00A0}KG 'x' ä &unknown; AT&T")
        XCTAssertEqual(MailText.plain("Tom &amp; Jerry &#39;x&#39; &auml;"), "Tom & Jerry 'x' ä")
        let accent = MailText.plain("Caf&eacute;")
        let bullet = MailText.plain("a&bull;b")
        let trademark = MailText.plain("Pro&trade;")
        XCTExpectFailure("BUG-4-19: only 26 named entities are known, the rest stays raw") {
            XCTAssertEqual(accent, "Café")
        }
        XCTExpectFailure("BUG-4-19: only 26 named entities are known, the rest stays raw") {
            XCTAssertEqual(bullet, "a•b")
        }
        XCTExpectFailure("BUG-4-19: only 26 named entities are known, the rest stays raw") {
            XCTAssertEqual(trademark, "Pro™")
        }
    }

    func testPlainTextKeepsBlockBreaksAndTrimsSourceWhitespace() {
        let paragraphs = MailText.plain("<p>Hello</p><p>World</p>")
        let lineBreak = MailText.plain("Hello<br>World")
        XCTExpectFailure("BUG-4-17: MailText.plain removes every tag, so paragraphs and line breaks run together") {
            XCTAssertEqual(paragraphs, "Hello\nWorld")
        }
        XCTExpectFailure("BUG-4-17: MailText.plain removes every tag, so paragraphs and line breaks run together") {
            XCTAssertEqual(lineBreak, "Hello\nWorld")
        }
        let text = MailText.plain("\n    <div>\n      <p>Hi</p>\n    </div>\n")
        XCTExpectFailure("BUG-4-20: plain does not trim or collapse source whitespace, the text starts with blank lines and an indent") {
            XCTAssertEqual(text, "Hi")
        }
    }
}
