import Mail
import XCTest

final class ModelTextTests: XCTestCase {
    func testPlainTextDropsScriptStyleAndTags() {
        let html = "<style>p{color:red}</style><p>Hallo <b>Welt</b></p><script>alert(1)</script>"
        XCTAssertEqual(MailText.plain(html), "Hallo Welt")
    }

    func testPlainTextDecodesEntities() {
        XCTAssertEqual(MailText.plain("&quot;Volkswagen&quot; &amp; Co&nbsp;KG &#39;x&#x27; &auml; &unknown; AT&T"),
                       "\"Volkswagen\" & Co\u{00A0}KG 'x' ä &unknown; AT&T")
    }
}
