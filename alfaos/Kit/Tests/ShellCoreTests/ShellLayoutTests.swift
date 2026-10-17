import Foundation
import XCTest
@testable import ShellCore

final class LayoutTests: XCTestCase {
    private func widths(_ window: Double, _ state: LaneState, _ g: ShellGeometry, _ rules: AreaRules) -> [Double] {
        LaneLayout.widths(windowWidth: window, state: state, geometry: g, rules: rules).all
    }

    func testTheLanesFollowTheAccordionOfTheDeliveredShell() throws {
        let g = try Fixture.geometry()
        let rules = AreaRules(minimum: g.minimum)
        let rest = LaneState(rest: g.laneRest)
        let avail = LaneLayout.available(1512, g)
        XCTAssertEqual(widths(1512, rest, g, rules), [280, 896, 280])
        for window in [1512.0, 1200, 1024, 800, 640] {
            let w = widths(window, rest, g, rules)
            XCTAssertEqual(w.reduce(0, +), LaneLayout.available(window, g), "\(window)")
        }
        XCTAssertEqual(widths(700, rest, g, rules)[0], g.laneFolded)

        let foldedLeft = LaneLayout.drag(lane: .leading, proposed: g.foldAt - 1, start: [280, 896, 280], state: rest, geometry: g, rules: rules)
        XCTAssertEqual(widths(1512, foldedLeft, g, rules), [56, 1120, 280])
        let bothFolded = LaneLayout.drag(lane: .trailing, proposed: 0, start: [56, 1120, 280], state: foldedLeft, geometry: g, rules: rules)
        XCTAssertEqual(widths(1512, bothFolded, g, rules), [56, avail - 112, 56])
        let middleFolded = LaneLayout.toggleFold(lane: .center, state: rest)
        XCTAssertEqual(widths(1512, middleFolded, g, rules)[1], g.laneFolded)
        XCTAssertEqual(widths(1512, middleFolded, g, rules).reduce(0, +), avail)

        let wide = LaneLayout.drag(lane: .trailing, proposed: 900, start: [280, 896, 280], state: rest, geometry: g, rules: rules)
        XCTAssertEqual(widths(1512, wide, g, rules), [56, 500, 900])

        for lane in [Lane.leading, .trailing] {
            let held = LaneLayout.drag(lane: lane, proposed: 150, start: [280, 896, 280], state: rest, geometry: g, rules: AreaRules.rules(for: "mail", geometry: g))
            XCTAssertEqual(widths(1512, held, g, rules)[lane.index], 224, lane.rawValue)
        }

        let folded = LaneLayout.toggleFold(lane: .trailing, state: LaneLayout.drag(lane: .trailing, proposed: 240, start: [280, 896, 280], state: rest, geometry: g, rules: rules))
        XCTAssertEqual(widths(1512, LaneLayout.toggleFold(lane: .trailing, state: folded), g, rules), [280, 936, 240])
        let maximized = LaneLayout.toggleMaximize(lane: .center, state: rest)
        XCTAssertEqual(widths(1512, maximized, g, rules), [56, avail - 112, 56])
        XCTAssertNil(LaneLayout.toggleMaximize(lane: .center, state: maximized).maximized)
    }
}

final class BlobTests: XCTestCase {
    func testHomeSitsInTheStripAtTheMargin() throws {
        let g = try Fixture.geometry()
        let origin = BlobPlacement.home(geometry: g).origin(window: Fixture.screen, geometry: g)
        XCTAssertEqual(origin, Point(x: 16, y: 16))
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
        XCTAssertEqual(top.origin, Point(x: 16, y: 64))
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
        XCTAssertFalse(model.laneState("settings").folded[0])
        XCTAssertTrue(model.laneState("mail").folded[0])
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
        XCTAssertEqual(restored.laneState("mail").preferred[2], 250)
    }

    private func model(snapshot: ShellSnapshot? = nil) throws -> ShellModel {
        ShellModel(directory: try Fixture.directory(), geometry: try Fixture.geometry(), window: Fixture.screen, snapshot: snapshot)
    }

}
