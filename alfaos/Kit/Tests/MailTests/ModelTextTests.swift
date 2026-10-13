import Mail
import XCTest

final class ModelTextTests: XCTestCase {
    func testPlainTextUsesTheSharedConverter() {
        XCTAssertEqual(MailText.plain("<style>p{color:red}</style><p>Hello</p><p>World &amp; Co</p>"), "Hello\nWorld & Co")
    }
}
