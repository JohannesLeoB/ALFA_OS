import ShellCore
import XCTest

final class TwoStepTests: XCTestCase {
    func testOnlyTheSecondPressOnTheSameItemGoesThrough() {
        var gate = TwoStep<String>()
        XCTAssertFalse(gate.press("a"))
        XCTAssertEqual(gate.armed, "a")
        XCTAssertFalse(gate.press("b"))
        XCTAssertEqual(gate.armed, "b")
        XCTAssertTrue(gate.press("b"))
        XCTAssertNil(gate.armed)
        XCTAssertFalse(gate.press("b"))
        gate.cancel()
        XCTAssertNil(gate.armed)
        XCTAssertFalse(gate.press("b"))
    }
}
