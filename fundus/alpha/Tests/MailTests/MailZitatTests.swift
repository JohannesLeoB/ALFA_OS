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
        let text = GoogleGmailClient.stripHTML(html)
        XCTAssertFalse(text.contains("padding"), "CSS darf nicht im Text landen")
        XCTAssertFalse(text.contains("font-face"))
        XCTAssertFalse(text.contains("var a"))
        XCTAssertFalse(text.contains("Weg"), "der Titel gehört nicht in den Text")
        XCTAssertTrue(text.contains("Hallo Person A,"))
        XCTAssertTrue(text.contains("Anbei der Schein."))
    }

    func testParagraphsBecomeLinesInsteadOfOneBlob() {
        let text = GoogleGmailClient.stripHTML("<p>Eins</p><p>Zwei</p>Drei<br>Vier")
        XCTAssertEqual(text, "Eins\nZwei\nDrei\nVier")
    }

    func testCommentsAreDropped() {
        XCTAssertEqual(GoogleGmailClient.stripHTML("A<!-- [if mso]><table><![endif] -->B"), "A B")
    }

    func testAQuoteWithoutADateDoesNotSayAmNothing() {
        let withoutDate = GoogleGmailMessage(
            id: "1", threadID: "1", subject: "S", from: "Anthropic", snippet: "", receivedAt: nil)
        XCTAssertTrue(withoutDate.quotedBody("Text").hasPrefix("\n\n— Anthropic schrieb:\n"))
    }
}
