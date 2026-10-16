import XCTest
@testable import ShellCore

final class DesignTests: XCTestCase {
    func testTheDeliveredSheetAgreesWithTheValuesTheCodeAlreadyUses() throws {
        let theme = try Fixture.theme()
        let pairs: [(Double, ThemeKey)] = [
            (Design.Size.laneRestWidth, .componentLaneRestingWidth),
            (Design.Size.foldedWidth, .componentLaneFoldedWidth),
            (Design.Size.foldThreshold, .componentLaneFoldThreshold),
            (Design.Size.headerHeight, .componentLaneHeaderHeight),
            (Design.Size.blobHeight, .componentBlobHeight),
            (Design.Size.blobAwakeWidth, .componentBlobAwakeWidth),
            (Design.Size.edge, .componentLaneEdge),
            (Design.Size.gutter, .componentLaneGap),
            (Design.Radius.lane, .componentLaneRadius),
            (Design.Radius.row, .radiusRow),
        ]
        for (value, key) in pairs {
            XCTAssertEqual(value, theme.length(key), key.rawValue)
        }
        XCTAssertEqual(Design.Duration.stack, theme.duration(.motionDurationStack), accuracy: 1e-9)
        XCTAssertEqual(DesignColors.light.ground, RGB(1, 1, 1, 1))
        XCTAssertEqual(DesignColors.dark.ground.red, 13.0 / 255.0, accuracy: 0.001)
        XCTAssertFalse(DesignStamp.adoptedAt.isEmpty)
        XCTAssertEqual(Design.Radius.contextMenu, 16)
        XCTAssertEqual(Design.Radius.card, 20)
    }
}
