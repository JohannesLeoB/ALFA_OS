import XCTest
@testable import ShellCore

final class DesignTests: XCTestCase {
    func testTheShellGeometryReadsTheDeliveredSheet() throws {
        let g = try Fixture.geometry()
        XCTAssertEqual(g.laneRest, Design.Size.laneRestWidth)
        XCTAssertEqual(g.foldAt, Design.Size.foldThreshold)
        XCTAssertEqual(g.blobTop, Design.Size.edge)
        XCTAssertEqual(g.strip, Design.Size.edge + Design.Size.blobHeight + Design.Size.gutter)
        XCTAssertEqual(g.blobAwakeWidth, Design.Size.blobAwakeWidth)
        XCTAssertEqual(DesignColors.light.ground, RGB(1, 1, 1, 1))
        XCTAssertEqual(DesignColors.dark.ground.red, 13.0 / 255.0, accuracy: 0.001)
        XCTAssertEqual(CardStack.tops(count: 6), [8, 16, 24, 68, 112, 156])
        XCTAssertEqual(CardStack.tops(count: 3), [8, 52, 96])
        XCTAssertFalse(DesignStamp.adoptedAt.isEmpty)
    }
}
