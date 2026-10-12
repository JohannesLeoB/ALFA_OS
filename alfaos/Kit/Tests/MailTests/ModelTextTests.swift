import Mail
import XCTest

final class ModelTextTests: XCTestCase {
    func testPlainTextDropsScriptStyleAndTags() {
        let html = "<style>p{color:red}</style><p>Hallo <b>Welt</b></p><script>alert(1)</script>"
        XCTAssertEqual(MailText.plain(html), "Hallo Welt")
    }
}
