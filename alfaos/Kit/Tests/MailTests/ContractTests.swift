import Hub
import Mail
import struct MykilosKit.EmailDraft
import XCTest

final class ContractTests: XCTestCase {
    func testOutboxItemStartsWaitingWithoutAttempts() {
        let item = OutboxItem(inlet: "a", draft: EmailDraft(to: "z@x", subject: "s", body: "b"))
        XCTAssertEqual(item.state, .waiting)
        XCTAssertEqual(item.attempts, 0)
    }
}
