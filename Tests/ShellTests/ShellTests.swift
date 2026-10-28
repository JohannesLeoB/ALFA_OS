import Core
import Design
import Foundation
@testable import Shell
import XCTest

private let directoryJSON = """
{"groups":[
{"id":"communication","titleKey":"group.communication","apps":[{"id":"mail","titleKey":"app.mail","lanes":{"leadingKey":"lane.folders","trailingKey":null}}]},
{"id":"core","titleKey":"group.core","apps":[{"id":"settings","titleKey":"app.settings","lanes":{}}]}
]}
"""

private let titles = ["app.mail": "Mail", "app.settings": "Einstellungen", "group.communication": "Kommunikation", "group.core": "Kern"]

private func loadDirectory() throws -> AppDirectory {
    try AppDirectory(data: Data(directoryJSON.utf8))
}

final class ShellTests: XCTestCase {
    private let measure = Measure()
    private let screen = ShellValues.previewScreen

    private func widths(_ window: Double, _ mode: LaneMode) -> [Double] {
        LaneLayoutEngine.widths(windowWidth: window, mode: mode, measure: measure, rules: AreaRules(minimum: measure.minimum)).all
    }

    func testMeasureComesFromTokens() {
        XCTAssertEqual(measure.margin, 16)
        XCTAssertEqual(measure.gap, 12)
        XCTAssertEqual(measure.strip, 68)
        XCTAssertEqual(measure.minimum, [280, 280, 280])
        XCTAssertEqual(measure.windowMin, BlobSize(width: 896, height: 582))
        XCTAssertEqual(measure.windowMin(screen: BlobSize(width: 0, height: 0)), BlobSize(width: 896, height: 896))
        XCTAssertEqual(measure.laneHeight(BlobSize(width: 1512, height: 982)), 898)
    }

    func testMailLeftLaneDragsBetweenItsLimits() {
        let rest = LaneMode(rest: measure.laneRest)
        let start = widths(1512, rest)
        let mail = AreaRules.area("mail", measure: measure)
        let drag = { (proposed: Double, rules: AreaRules) in
            LaneLayoutEngine.drag(lane: .leading, proposed: proposed, start: start, mode: rest, measure: self.measure, rules: rules).preferred[0]
        }
        XCTAssertEqual(drag(400, mail), 280)
        XCTAssertEqual(drag(200, mail), 224)
        XCTAssertEqual(drag(250, mail), 250)
        XCTAssertEqual(drag(400, AreaRules.area("settings", measure: measure)), 400)
    }

    func testMenuWidthSnapsToTheGrid() {
        XCTAssertEqual(MenuWidthEngine.width(fitting: 40), 168)
        XCTAssertEqual(MenuWidthEngine.width(fitting: 169), 224)
        XCTAssertEqual(MenuWidthEngine.width(fitting: 224), 224)
        XCTAssertEqual(MenuWidthEngine.width(fitting: 600), 280)
    }

    func testLanesFollowTheAccordion() {
        let rest = LaneMode(rest: measure.laneRest)
        let avail = LaneLayoutEngine.available(1512, measure)
        XCTAssertEqual(widths(1512, rest), [280, 896, 280])
        for window in [1512.0, 1200, 1024, 800, 640] {
            XCTAssertEqual(widths(window, rest).reduce(0, +), LaneLayoutEngine.available(window, measure), "\(window)")
        }
        XCTAssertEqual(widths(700, rest)[0], measure.laneFolded)
        let rules = AreaRules(minimum: measure.minimum)
        let foldedLeft = LaneLayoutEngine.drag(lane: .leading, proposed: measure.foldAt - 1, start: [280, 896, 280], mode: rest, measure: measure, rules: rules)
        XCTAssertEqual(widths(1512, foldedLeft), [56, 1120, 280])
        let bothFolded = LaneLayoutEngine.drag(lane: .trailing, proposed: 0, start: [56, 1120, 280], mode: foldedLeft, measure: measure, rules: rules)
        XCTAssertEqual(widths(1512, bothFolded), [56, avail - 112, 56])
        let middleFolded = LaneLayoutEngine.toggleFold(lane: .center, mode: rest)
        XCTAssertEqual(widths(1512, middleFolded)[1], measure.laneFolded)
        XCTAssertEqual(widths(1512, middleFolded).reduce(0, +), avail)
        let wide = LaneLayoutEngine.drag(lane: .trailing, proposed: 900, start: [280, 896, 280], mode: rest, measure: measure, rules: rules)
        XCTAssertEqual(widths(1512, wide), [56, 500, 900])
        XCTAssertEqual(wide.preferred[1], 0)
        XCTAssertTrue(wide.pinned)
        XCTAssertEqual(LaneLayoutEngine.drag(lane: .center, proposed: 100, start: [280, 896, 280], mode: rest, measure: measure, rules: rules), rest)
        for lane in [LaneKind.leading, .trailing] {
            let held = LaneLayoutEngine.drag(lane: lane, proposed: 150, start: [280, 896, 280], mode: rest, measure: measure, rules: rules)
            XCTAssertEqual(widths(1512, held)[lane.index], 280, lane.rawValue)
        }
        let maximized = LaneLayoutEngine.toggleMaximize(lane: .center, mode: rest)
        XCTAssertEqual(widths(1512, maximized), [56, avail - 112, 56])
        XCTAssertNil(LaneLayoutEngine.toggleMaximize(lane: .center, mode: maximized).maximized)
        let laid = LaneLayoutEngine.widths(windowWidth: 1512, mode: rest, measure: measure, rules: rules)
        XCTAssertEqual(laid.width(.center), laid.center)
        XCTAssertEqual(LaneKind.allCases.map(laid.width), laid.all)
    }

    func testLaneKindHeadMetrics() {
        XCTAssertEqual(LaneKind.allCases.map(\.index), [0, 1, 2])
        XCTAssertEqual(LaneKind.trailing.headLeading, Tokens.Size.headPadLeftStack)
        XCTAssertEqual(LaneKind.leading.headLeading, Tokens.Size.headPadLeftList)
        XCTAssertEqual(LaneKind.center.headGap, Tokens.Size.headGapList)
        XCTAssertEqual(LaneKind.trailing.headGap, Tokens.Size.headGapStack)
        XCTAssertEqual(LaneKind.center.headTrailing, Tokens.Size.headPadRight)
    }

    func testBlobPlacementSettlesAndDocks() {
        let home = BlobPlacement.home(measure: measure)
        XCTAssertEqual(home, BlobPlacement(edge: .top, offset: 16))
        XCTAssertFalse(home.isDocked)
        XCTAssertEqual(home.origin(window: screen, measure: measure), BlobPoint(x: 16, y: 16))
        let still = BlobPoint(x: 0, y: 0)
        XCTAssertEqual(BlobPlacement.settle(dropAt: BlobPoint(x: 100, y: 60), velocity: still, window: screen, measure: measure), home)
        let right = BlobPlacement.settle(dropAt: BlobPoint(x: 1400, y: 500), velocity: still, window: screen, measure: measure)
        XCTAssertEqual(right.edge, .trailing)
        XCTAssertEqual(right.origin(window: screen, measure: measure).x, 1512 - measure.blobDock)
        let left = BlobPlacement.settle(dropAt: BlobPoint(x: 200, y: 500), velocity: still, window: screen, measure: measure)
        XCTAssertEqual(left.edge, .leading)
        XCTAssertEqual(left.origin(window: screen, measure: measure).x, 0)
        let low = BlobPlacement(edge: .leading, offset: 5000)
        XCTAssertEqual(low.origin(window: screen, measure: measure).y, 982 - 40 - 16)
        XCTAssertEqual(BlobPlacement(edge: .leading, offset: 1).origin(window: screen, measure: measure).y, measure.strip)
        XCTAssertEqual(low.normalized, low)
        XCTAssertEqual(BlobPlacement(edge: .top, offset: 9).normalized, BlobPlacement(edge: .top, offset: 9))
        XCTAssertFalse(home.opensUpward(window: screen, measure: measure))
        XCTAssertTrue(low.opensUpward(window: screen, measure: measure))
        XCTAssertEqual(home.menuRoom(window: screen, measure: measure), 982 - 16 - 16 - 40 - 8)
        XCTAssertEqual(BlobPlacement.awakeWidth(label: 10), Tokens.Size.blobAwakeWidth)
        XCTAssertEqual(BlobPlacement.awakeWidth(label: 400), Tokens.Size.blobPopupFallbackWidth)
    }

    func testBlobPlacementRoundTripsAsJSON() throws {
        let placement = BlobPlacement(edge: .trailing, offset: 120)
        let data = try JSONEncoder().encode(placement)
        XCTAssertEqual(try JSONDecoder().decode(BlobPlacement.self, from: data), placement)
        XCTAssertThrowsError(try JSONDecoder().decode(BlobPlacement.self, from: Data(#"{"edge":"bottom","offset":1}"#.utf8)))
    }

    func testBlobStretchFollowsPointerSpeed() {
        XCTAssertEqual(BlobStretch(history: []), .none)
        XCTAssertEqual(BlobStretch(history: [PointerSample(point: BlobPoint(x: 0, y: 0), time: 0)]), .none)
        let slow = BlobStretch(history: [PointerSample(point: BlobPoint(x: 0, y: 0), time: 0), PointerSample(point: BlobPoint(x: 1, y: 0), time: 1)])
        XCTAssertEqual(slow.angle, 0, accuracy: 1e-9)
        XCTAssertEqual(slow.amount, ShellValues.stretchPerSpeed, accuracy: 1e-9)
        let fast = BlobStretch(history: [PointerSample(point: BlobPoint(x: 0, y: 0), time: 0), PointerSample(point: BlobPoint(x: 0, y: 1000), time: 0.001)])
        XCTAssertEqual(fast.angle, Double.pi / 2, accuracy: 1e-9)
        XCTAssertEqual(fast.amount, Tokens.Size.blobStretchMax, accuracy: 1e-9)
    }

    func testDirectoryDrivesMenuAndSearch() throws {
        let directory = try loadDirectory()
        XCTAssertEqual(directory.apps.map(\.id), ["mail", "settings"])
        XCTAssertEqual(directory.first?.id, "mail")
        XCTAssertNil(directory.app("nowhere"))
        XCTAssertEqual(directory.app("mail")?.lanes.leadingKey, "lane.folders")
        XCTAssertNil(directory.app("mail")?.lanes.trailingKey)
        let rows = directory.rows(matching: "stell", title: { titles[$0] ?? $0 })
        XCTAssertEqual(rows.map(\.group.id), ["core"])
        XCTAssertEqual(directory.rows(matching: " ", title: { $0 }).count, 2)
        XCTAssertEqual(directory.rows(matching: "kommun", title: { titles[$0] ?? $0 }).map(\.group.id), ["communication"])
        let lines = directory.menu(matching: "", title: { $0 })
        XCTAssertEqual(lines.map(\.id), ["mail", "separator.1", "settings"])
        XCTAssertEqual(lines.compactMap(\.entry).map(\.id), ["mail", "settings"])
        XCTAssertTrue(directory.menu(matching: "zzz", title: { $0 }).isEmpty)
    }

    @MainActor
    func testSelectClosesMenuAndKeepsLaneModePerArea() throws {
        let model = DeskState(directory: try loadDirectory(), measure: measure, window: screen)
        var seen: [Snapshot] = []
        model.onChange = { seen.append($0) }
        XCTAssertEqual(model.currentID, "mail")
        model.toggleMenu()
        XCTAssertTrue(model.menuOpen)
        XCTAssertEqual(model.blobWidth, measure.menuWidth)
        model.toggleFold(.leading)
        model.select("settings")
        XCTAssertFalse(model.menuOpen)
        XCTAssertFalse(model.laneMode("settings").folded[0])
        XCTAssertTrue(model.laneMode("mail").folded[0])
        model.select("nowhere")
        XCTAssertEqual(model.currentID, "settings")
        XCTAssertEqual(seen.count, 2)
        XCTAssertEqual(model.current?.id, "settings")
    }

    @MainActor
    func testAssistantExcludesMenuAndSnapshotRoundTrips() throws {
        let directory = try loadDirectory()
        let model = DeskState(directory: directory, measure: measure, window: screen)
        model.toggleMenu()
        model.toggleAssistant()
        XCTAssertTrue(model.assistantOpen)
        XCTAssertFalse(model.menuOpen)
        model.toggleAssistant()
        XCTAssertNil(model.mode)
        model.beginBlobDrag()
        XCTAssertTrue(model.dragging)
        model.dropBlob(center: BlobPoint(x: 1450, y: 500), velocity: BlobPoint(x: 0, y: 0))
        XCTAssertFalse(model.dragging)
        XCTAssertEqual(model.blob.edge, .trailing)
        XCTAssertTrue(model.docked)
        model.setHovering(true)
        XCTAssertEqual(model.blobWidth, measure.blobDock + ShellValues.dockHoverGrow)
        model.select("settings")
        let suite = "ShellTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ShellStore(defaults: defaults)
        XCTAssertNil(store.load())
        store.save(model.snapshot)
        let restored = DeskState(directory: directory, measure: measure, window: screen, snapshot: store.load())
        XCTAssertEqual(restored.currentID, "settings")
        XCTAssertEqual(restored.blob, model.blob)
        XCTAssertEqual(restored.face, .orb)
        let stale = try JSONDecoder().decode(Snapshot.self, from: Data(#"{"currentID":"gone","lanes":{},"blob":{"edge":"top","offset":3}}"#.utf8))
        XCTAssertEqual(DeskState(directory: directory, measure: measure, window: screen, snapshot: stale).currentID, "mail")
        XCTAssertEqual(DeskState(directory: directory, measure: measure, window: screen, snapshot: model.snapshot, startID: "mail").currentID, "mail")
        XCTAssertEqual(DeskState(directory: directory, measure: measure, window: screen, snapshot: model.snapshot, startID: "gone").currentID, "settings")
    }

    @MainActor
    func testHotRowMovesWithinBounds() throws {
        let directory = try loadDirectory()
        let model = DeskState(directory: directory, measure: measure, window: screen)
        let entries = directory.apps
        model.moveHot(down: true, count: entries.count)
        XCTAssertEqual(model.hot, 0)
        model.moveHot(down: true, count: entries.count)
        model.moveHot(down: true, count: entries.count)
        XCTAssertEqual(model.hot, 1)
        model.moveHot(down: false, count: entries.count)
        XCTAssertEqual(model.hot, 0)
        model.moveHot(down: true, count: 0)
        XCTAssertEqual(model.hot, 0)
        model.aim(1)
        model.chooseHot(entries)
        XCTAssertEqual(model.currentID, "settings")
        model.query = "x"
        model.aim(1)
        model.query = "y"
        XCTAssertEqual(model.hot, -1)
        model.aim(1)
        model.clearHot()
        XCTAssertEqual(model.hot, -1)
    }

    @MainActor
    func testLaneDragStepResetAndStrip() throws {
        let model = DeskState(directory: try loadDirectory(), measure: measure, window: screen)
        XCTAssertEqual(model.widths.all, [280, 896, 280])
        model.dragLane(.trailing, proposed: 900)
        XCTAssertTrue(model.laneDragging)
        XCTAssertEqual(model.widths.all, [56, 500, 900])
        model.endLaneDrag()
        XCTAssertFalse(model.laneDragging)
        model.resetLane()
        XCTAssertEqual(model.widths.all, [280, 896, 280])
        model.stepLane(.leading, by: 40)
        XCTAssertEqual(model.widths.all, [280, 896, 280])
        model.stepLane(.leading, by: -40)
        XCTAssertEqual(model.widths.all, [240, 936, 280])
        model.toggleMaximize(.center)
        XCTAssertNotNil(model.laneMode("mail").maximized)
        model.openStrip(.leading)
        XCTAssertNil(model.laneMode("mail").maximized)
        model.toggleFold(.leading)
        XCTAssertTrue(model.laneMode("mail").folded[0])
        model.openStrip(.leading)
        XCTAssertFalse(model.laneMode("mail").folded[0])
        model.resize(BlobSize(width: 1200, height: 800))
        XCTAssertEqual(model.window.width, 1200)
    }

    @MainActor
    func testEmptyStackFoldsTrailingLaneAfterEbb() throws {
        let model = DeskState(directory: try loadDirectory(), measure: measure, window: screen)
        model.stack(empty: true, still: true)
        XCTAssertTrue(model.ebb)
        XCTAssertEqual(model.widths.trailing, measure.laneFolded)
        model.stack(empty: true, still: true)
        model.stack(empty: false, still: true)
        XCTAssertFalse(model.ebb)
        XCTAssertTrue(model.slowLane)
        XCTAssertEqual(model.widths.trailing, 280)
    }

    @MainActor
    func testAwakeNeedsRestingBlob() throws {
        let model = DeskState(directory: try loadDirectory(), measure: measure, window: screen)
        model.setAwake(true)
        XCTAssertTrue(model.awake)
        model.labelWidth = 10
        XCTAssertEqual(model.blobWidth, Tokens.Size.blobAwakeWidth)
        model.toggleMenu()
        XCTAssertFalse(model.awake)
        model.setAwake(true)
        XCTAssertFalse(model.awake)
    }

    func testIconPathsParseAllCommands() {
        XCTAssertEqual(Icon.allCases.count, 52)
        for icon in Icon.allCases {
            XCTAssertFalse(icon.path.segments.isEmpty, icon.rawValue)
        }
        XCTAssertEqual(Icon.plus.path.segments, [.move(x: 8, y: 3), .line(x: 8, y: 13), .move(x: 3, y: 8), .line(x: 13, y: 8)])
        XCTAssertEqual(IconPath(data: "M1 1h2v3z").segments, [.move(x: 1, y: 1), .line(x: 3, y: 1), .line(x: 3, y: 4), .close])
        XCTAssertEqual(IconPath(data: "M0 0 1 1").segments, [.move(x: 0, y: 0), .line(x: 1, y: 1)])
        XCTAssertEqual(IconPath(data: "M0,0C1 1 2 2 3 3S5 5 6 6").segments.count, 3)
        XCTAssertEqual(IconPath(data: "M0 0A0 0 0 0 1 4 4").segments, [.move(x: 0, y: 0), .line(x: 4, y: 4)])
        let arc = IconPath(data: "M0 0a2 2 0 0 1 4 0").segments
        guard case .cubic(_, _, _, _, let x, let y) = arc.last else { return XCTFail() }
        XCTAssertEqual(x, 4, accuracy: 1e-9)
        XCTAssertEqual(y, 0, accuracy: 1e-9)
        XCTAssertEqual(IconPath(data: "").segments, [])
        XCTAssertEqual(StripFace.glyph(.envelope), StripFace.glyph(.envelope))
    }

    func testCardStackTopsAndLevels() {
        XCTAssertEqual(CardStackEngine.tops(count: 0), [])
        XCTAssertEqual(CardStackEngine.tops(count: 3), [8, 52, 96])
        XCTAssertEqual(CardStackEngine.tops(count: 5), [8, 16, 60, 104, 148])
        XCTAssertEqual(CardStackEngine.tops(count: 2, start: 0), [0, 44])
        XCTAssertEqual(CardStackEngine.fannedTops(count: 0), [])
        XCTAssertEqual(CardStackEngine.fannedTops(count: 4), [0, 52, 104, 156])
        XCTAssertEqual(CardStackEngine.levelIndex(depth: 0), -1)
        XCTAssertEqual(CardStackEngine.levelIndex(depth: 2), 1)
        XCTAssertEqual(CardStackEngine.levelIndex(depth: 9), 4)
        XCTAssertEqual(CardStackEngine.metaOpacity(depth: 3), 0.72)
        XCTAssertEqual(CardStackEngine.metaOpacity(depth: 4), 0.95)
        XCTAssertEqual(OverviewSize.allCases.map(\.tileHeight), [144, 176, 248])
        XCTAssertEqual(OverviewSize.allCases.map(\.tileMinWidth), [200, 232, 320])
        XCTAssertEqual(OverviewSize.allCases.map(\.lines), [3, 4, 8])
    }

    func testCommandBarMovesLowestPriorityButtonsIntoOverflow() {
        func button(_ id: String, _ priority: Int, off: Bool = false) -> CommandSlot<String> {
            CommandSlot(id: id, action: id, priority: priority, off: off)
        }
        let main = [button("a", 1), CommandSlot<String>.separator, button("b", 2), button("c", 3, off: true)]
        let wide = CommandBarEngine.plan(main: main, tail: [], fan: [], fold: [], staticMore: false, width: 1000)
        XCTAssertEqual(wide.main, main)
        XCTAssertTrue(wide.overflow.isEmpty)
        XCTAssertTrue(wide.end.isEmpty)
        let narrow = CommandBarEngine.plan(main: main, tail: [button("t", 0)], fan: [button("f", 0)], fold: [], staticMore: false, width: 160)
        XCTAssertEqual(narrow.overflow.map(\.id), ["b"])
        XCTAssertEqual(narrow.main.map(\.id), ["a"])
        XCTAssertEqual(narrow.end.map(\.id), ["t", "more", "separator", "f"])
        let none = CommandBarEngine.plan(main: main, tail: [], fan: [], fold: [], staticMore: true, width: 0)
        XCTAssertEqual(none.main.map(\.id), [])
        XCTAssertEqual(none.overflow.map(\.id), ["a", "b"])
        XCTAssertEqual(none.end.map(\.id), ["more"])
    }

    func testHoldFillsForwardAndReleases() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let press = HoldEngine(from: 0, forward: true, start: start)
        XCTAssertEqual(press.length, Tokens.Duration.confirmHold, accuracy: 1e-9)
        XCTAssertEqual(press.fill(at: start), 0, accuracy: 1e-9)
        XCTAssertEqual(press.fill(at: start.addingTimeInterval(press.length / 2)), 0.5, accuracy: 1e-9)
        XCTAssertEqual(press.fill(at: start.addingTimeInterval(10)), 1, accuracy: 1e-9)
        let release = HoldEngine(from: 0.5, forward: false, start: start)
        XCTAssertEqual(release.length, Tokens.Duration.confirmRelease * 0.5, accuracy: 1e-9)
        XCTAssertEqual(release.fill(at: start.addingTimeInterval(10)), 0, accuracy: 1e-9)
        XCTAssertEqual(HoldEngine(from: 1, forward: true, start: start).fill(at: start), 1, accuracy: 1e-9)
    }

    func testEraseAndShakeFollowFill() {
        XCTAssertEqual(HoldEngine.eraseStops(fill: 0).map(\.opacity), [1, 1])
        let half = HoldEngine.eraseStops(fill: 0.5)
        XCTAssertEqual(half.count, 4)
        for (stop, expected) in zip(half, [0.0, 0.4, 0.6, 1.0]) { XCTAssertEqual(stop.location, expected, accuracy: 1e-9) }
        XCTAssertEqual(half[0].opacity, 0, accuracy: 1e-9)
        XCTAssertEqual(half[3].opacity, 1, accuracy: 1e-9)
        XCTAssertEqual(HoldEngine.shake(fill: Tokens.Confirm.shakeFrom), 0)
        XCTAssertEqual(HoldEngine.shake(fill: 0.1), 0)
        XCTAssertNotEqual(HoldEngine.shake(fill: 0.9), 0)
    }

    func testTileGridFlowsLikeAutoFill() {
        for n in 1...4 {
            let edge = Double(n) * 132 + Double(n - 1) * 8
            XCTAssertEqual(TileGrid.columns(width: edge, minimum: 132, gap: 8), n)
            XCTAssertEqual(TileGrid.columns(width: edge - 1, minimum: 132, gap: 8), max(1, n - 1))
        }
        XCTAssertEqual(TileGrid.columns(width: .infinity, minimum: 132, gap: 8), 1)
        XCTAssertEqual(TileGrid.columns(width: 500, minimum: 0, gap: 8), 1)
        XCTAssertEqual(TileGrid.columnWidth(width: 272, count: 2, gap: 8), 132)
        XCTAssertEqual(TileGrid.rowTops(top: 40, count: 5, columns: 2, height: 96, gap: 8), [40, 144, 248])
        XCTAssertEqual(TileGrid.rowTops(top: 40, count: 0, columns: 2, height: 96, gap: 8), [])
        XCTAssertEqual(TileGrid.rowTops(top: 40, count: 3, columns: 0, height: 96, gap: 8), [])
        let rows = [40.0, 144, 248]
        XCTAssertEqual(TileGrid.snap(10, rows: rows, inset: 8, limit: 500), 0)
        XCTAssertEqual(TileGrid.snap(25, rows: rows, inset: 8, limit: 500), 32)
        XCTAssertEqual(TileGrid.snap(120, rows: rows, inset: 8, limit: 500), 136)
        XCTAssertEqual(TileGrid.snap(400, rows: rows, inset: 8, limit: 500), 240)
        XCTAssertEqual(TileGrid.snap(400, rows: rows, inset: 8, limit: 200), 200)
        XCTAssertEqual(TileGrid.snap(-30, rows: [], inset: 8, limit: -5), 0)
    }

    func testTileGridActiveGroupFollowsTheHead() {
        let tops = [8.0, 640]
        XCTAssertEqual(TileGrid.active(tops: tops, offset: 0, reach: 32, viewport: 400, content: 1200), 0)
        XCTAssertEqual(TileGrid.active(tops: tops, offset: 607, reach: 32, viewport: 400, content: 1200), 0)
        XCTAssertEqual(TileGrid.active(tops: tops, offset: 608, reach: 32, viewport: 400, content: 1200), 1)
        XCTAssertEqual(TileGrid.active(tops: tops, offset: 500, reach: 32, viewport: 400, content: 902), 1)
        XCTAssertEqual(TileGrid.active(tops: tops, offset: 0, reach: 32, viewport: 400, content: 300), 0)
        XCTAssertEqual(TileGrid.active(tops: [.infinity, .infinity], offset: 0, reach: 32, viewport: 400, content: 1200), 0)
        XCTAssertEqual(TileGrid.active(tops: [], offset: 50, reach: 32, viewport: 400, content: 100), 0)
    }
}
