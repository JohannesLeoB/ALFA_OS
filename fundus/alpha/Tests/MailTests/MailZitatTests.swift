import XCTest
@testable import MykilosServices

final class MailZitatTests: XCTestCase {
    func testStyleAndScriptContentNeverReachesTheText() {
        let html = """
        <html><head><title>Weg</title><style>
        #outlook a { padding:0; }
        @font-face { font-family: 'X'; src: url('y.otf'); }
        </style></head>
        <body><script>var a = 1;</script><p>Hallo Person A,</p><p>Anbei der Schein.</p></body></html>
        """
        let text = HTMLText.plain(html)
        XCTAssertFalse(text.contains("padding"), "CSS darf nicht im Text landen")
        XCTAssertFalse(text.contains("font-face"))
        XCTAssertFalse(text.contains("var a"))
        XCTAssertFalse(text.contains("Weg"), "der Titel gehört nicht in den Text")
        XCTAssertTrue(text.contains("Hallo Person A,"))
        XCTAssertTrue(text.contains("Anbei der Schein."))
    }

    func testParagraphsBecomeLinesInsteadOfOneBlob() {
        let text = HTMLText.plain("<p>Eins</p><p>Zwei</p>Drei<br>Vier")
        XCTAssertEqual(text, "Eins\nZwei\nDrei\nVier")
    }

    func testCommentsAreDropped() {
        XCTAssertEqual(HTMLText.plain("A<!-- [if mso]><table><![endif] -->B"), "A B")
    }

    func testConditionalCommentsDropTheirContent() {
        XCTAssertEqual(HTMLText.plain("<!--[if mso]><p>Only Outlook</p><![endif]--><p>Real</p>"), "Real")
    }

    func testEntitiesAreDecodedOnceAndUnknownOnesStayRaw() {
        XCTAssertEqual(
            HTMLText.plain("&quot;Volkswagen&quot; &amp; Co&nbsp;KG &#39;x&#x27; &auml; &unknown; AT&T Caf&eacute; a&bull;b Pro&trade;"),
            "\"Volkswagen\" & Co KG 'x' ä &unknown; AT&T Café a•b Pro™")
        XCTAssertEqual(HTMLText.plain("&amp;lt;"), "&lt;")
    }

    func testSourceWhitespaceIsCollapsedAndTrimmed() {
        XCTAssertEqual(HTMLText.plain("\n    <div>\n      <p>Hi</p>\n    </div>\n"), "Hi")
    }

    func testAQuoteWithoutADateDoesNotSayAmNothing() {
        let withoutDate = GoogleGmailMessage(
            id: "1", threadID: "1", subject: "S", from: "Anthropic", snippet: "", receivedAt: nil)
        XCTAssertTrue(withoutDate.quotedBody("Text").hasPrefix("\n\n— Anthropic schrieb:\n"))
    }
}
