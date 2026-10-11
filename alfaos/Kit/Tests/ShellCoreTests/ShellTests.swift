import Foundation
import XCTest
@testable import ShellCore

final class LayoutTests: XCTestCase {
    func testRestingWidthsOnTheLargeScreen() throws {
        let g = try Fixture.geometry()
        let widths = LaneLayout.widths(windowWidth: 1512, state: LaneState(rest: g.laneRest), geometry: g)
        XCTAssertEqual([widths.leading, widths.center, widths.trailing], [300, 856, 300])
        XCTAssertEqual(widths.notes, [])
    }

    func testNarrowWindowNarrowsThenFolds() throws {
        let g = try Fixture.geometry()
        let state = LaneState(rest: g.laneRest)
        let medium = LaneLayout.widths(windowWidth: 1024, state: state, geometry: g)
        XCTAssertGreaterThanOrEqual(medium.center, g.centerMin)
        XCTAssertEqual(medium.trailing, g.laneMin)
        let small = LaneLayout.widths(windowWidth: 960, state: state, geometry: g)
        XCTAssertGreaterThanOrEqual(small.center, g.centerMin)
        XCTAssertTrue(small.notes.contains(.trailingNarrowed))
    }

    func testDragFoldsBelowThresholdAndClampsInRange() throws {
        let g = try Fixture.geometry()
        var state = LaneState(rest: g.laneRest)
        state = LaneLayout.drag(lane: .leading, proposed: g.foldAt - 1, state: state, windowWidth: 1512, geometry: g)
        XCTAssertTrue(state.leadingFolded)
        state = LaneLayout.drag(lane: .leading, proposed: 900, state: state, windowWidth: 1512, geometry: g)
        XCTAssertFalse(state.leadingFolded)
        XCTAssertEqual(state.leading, g.laneMax)
        state = LaneLayout.drag(lane: .leading, proposed: g.foldAt + 1, state: state, windowWidth: 1512, geometry: g)
        XCTAssertEqual(state.leading, g.laneMin)
    }

    func testMaximizeFoldsTheOthersAndResetRestores() throws {
        let g = try Fixture.geometry()
        var state = LaneLayout.toggleMaximize(lane: .center, state: LaneState(rest: g.laneRest))
        let widths = LaneLayout.widths(windowWidth: 1512, state: state, geometry: g)
        XCTAssertEqual([widths.leading, widths.trailing], [g.laneFolded, g.laneFolded])
        state = LaneLayout.reset(lane: .leading, state: state, geometry: g)
        XCTAssertNil(state.maximized)
        XCTAssertEqual(state.leading, g.laneRest)
    }
}

final class BlobTests: XCTestCase {
    func testHomeSitsInTheStripAtTheMargin() throws {
        let g = try Fixture.geometry()
        let origin = BlobPlacement.home(geometry: g).origin(window: Fixture.screen, geometry: g)
        XCTAssertEqual(origin, Point(x: 16, y: 12))
    }

    func testThrowSettlesAtTheNearestEdge() throws {
        let g = try Fixture.geometry()
        let placement = BlobPlacement.settle(dropAt: Point(x: 1400, y: 500), velocity: Point(x: 0, y: 0), window: Fixture.screen, geometry: g)
        XCTAssertEqual(placement.edge, .trailing)
        let thrown = BlobPlacement.settle(dropAt: Point(x: 700, y: 500), velocity: Point(x: -8000, y: 0), window: Fixture.screen, geometry: g)
        XCTAssertEqual(thrown.edge, .leading)
    }

    func testMenuOpensBelowAtTheTopAndAboveAtTheBottom() throws {
        let g = try Fixture.geometry()
        let top = BlobPlacement.home(geometry: g).menuOrigin(window: Fixture.screen, geometry: g)
        XCTAssertTrue(top.opensDownward)
        XCTAssertEqual(top.origin, Point(x: 16, y: 56))
        let bottom = BlobPlacement(edge: .bottom, offset: 16).menuOrigin(window: Fixture.screen, geometry: g)
        XCTAssertFalse(bottom.opensDownward)
    }
}

@MainActor
final class ModelTests: XCTestCase {
    func testDirectoryDrivesTheMenuAndSearch() throws {
        let directory = try Fixture.directory()
        XCTAssertEqual(directory.apps.map(\.id), ["mail", "settings"])
        let titles = ["app.mail": "Mail", "app.settings": "Einstellungen", "group.communication": "Kommunikation", "group.core": "Kern"]
        let rows = directory.rows(matching: "stell", title: { titles[$0] ?? $0 })
        XCTAssertEqual(rows.map(\.group.id), ["core"])
        XCTAssertEqual(directory.rows(matching: "", title: { $0 }).count, 2)
    }

    func testSelectClosesTheMenuAndKeepsLaneStatePerArea() throws {
        let model = ShellModel(directory: try Fixture.directory(), geometry: try Fixture.geometry(), window: Fixture.screen)
        model.toggleMenu()
        XCTAssertEqual(model.phase, .menuOpen)
        model.toggleFold(.leading)
        model.select("settings")
        XCTAssertEqual(model.phase, .rest)
        XCTAssertFalse(model.laneState("settings").leadingFolded)
        XCTAssertTrue(model.laneState("mail").leadingFolded)
        model.select("nowhere")
        XCTAssertEqual(model.currentID, "settings")
    }

    func testAssistantExcludesTheMenuAndSnapshotRoundTrips() throws {
        let g = try Fixture.geometry()
        let model = ShellModel(directory: try Fixture.directory(), geometry: g, window: Fixture.screen)
        model.toggleMenu()
        model.toggleAssistant()
        XCTAssertTrue(model.assistantOpen)
        XCTAssertFalse(model.menuOpen)
        model.dragLane(.trailing, proposed: 250)
        let data = try JSONEncoder().encode(model.snapshot)
        let restored = ShellModel(directory: try Fixture.directory(), geometry: g, window: Fixture.screen, snapshot: try JSONDecoder().decode(ShellSnapshot.self, from: data))
        XCTAssertEqual(restored.laneState("mail").trailing, 250)
    }
}
