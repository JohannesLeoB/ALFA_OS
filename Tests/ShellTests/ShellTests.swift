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

@MainActor
private final class FakeUnlock: UnlockPort {
    var touchID = true
    var available = true
    var outcomes: [UnlockMethod: [UnlockOutcome]] = [:]
    private(set) var asked: [UnlockMethod] = []
    private(set) var cancels = 0

    func unlock(_ method: UnlockMethod, reason: String) async -> UnlockOutcome {
        asked.append(method)
        return outcomes[method]?.isEmpty == false ? outcomes[method]!.removeFirst() : .granted
    }

    func cancel() {
        cancels += 1
    }
}

@MainActor
private final class FakeClock {
    var now: TimeInterval = 0
    var waits: [TimeInterval] = []
    var during: (() -> Void)?
    var budget = 0
    var idleBudget = 0
}

@MainActor
private final class PhaseLog {
    var seen: [LockPhase] = []
}

private let resignedName = Notification.Name("test.resigned")
private let becameName = Notification.Name("test.became")

@MainActor
private func lockState(_ port: FakeUnlock, _ clock: FakeClock, on: Bool = true, pause: LockPause = .oneMinute,
                       center: NotificationCenter = NotificationCenter()) -> LockState {
    LockState(port: port, on: on, pause: pause, reason: "reason", center: center, resigned: resignedName, became: becameName,
              now: { clock.now }) { wait in
        let start = clock.now
        clock.waits.append(wait)
        let idle = wait > LockState.unlockGrace
        guard (idle ? clock.idleBudget : clock.budget) > 0 else { throw CancellationError() }
        if idle { clock.idleBudget -= 1 } else { clock.budget -= 1 }
        let hook = clock.during
        clock.during = nil
        hook?()
        clock.now = start + wait
    }
}

final class ShellTests: XCTestCase {
    private let measure = Measure()
    private let screen = ShellValues.previewScreen
    private let mailLimits = AreaLimits(minimum: [.leading: Tokens.Size.mailLaneMinimumLeft], maximum: [.leading: Tokens.Size.mailLaneMaximumLeft])

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
        let mail = AreaRules(measure: measure, limits: mailLimits)
        let drag = { (proposed: Double, rules: AreaRules) in
            LaneLayoutEngine.drag(lane: .leading, proposed: proposed, start: start, mode: rest, measure: self.measure, rules: rules).preferred[0]
        }
        XCTAssertEqual(drag(400, mail), 280)
        XCTAssertEqual(drag(200, mail), 200)
        XCTAssertEqual(drag(250, mail), 250)
        XCTAssertEqual(drag(400, AreaRules(measure: measure, limits: AreaLimits())), 400)
        XCTAssertEqual(mail.minimum, [Tokens.Size.mailLaneMinimumLeft, measure.minimum[1], measure.minimum[2]])
        XCTAssertEqual(mail.maximum, [Tokens.Size.mailLaneMaximumLeft, nil, nil])
    }

    func testSqueezedLanesReturnWhenTheWindowGrows() throws {
        let rest = LaneMode(rest: measure.laneRest)
        let rules = AreaRules(minimum: measure.minimum)
        let small = widths(700, rest)
        XCTAssertEqual(small[0], measure.laneFolded)
        let nudged = LaneLayoutEngine.drag(lane: .trailing, proposed: small[2] + 8, start: small, mode: rest, measure: measure, rules: rules)
        XCTAssertEqual(widths(700, nudged)[0], measure.laneFolded)
        XCTAssertEqual(widths(1512, nudged)[0], 280)
        let wide = LaneLayoutEngine.drag(lane: .trailing, proposed: 900, start: [280, 896, 280], mode: rest, measure: measure, rules: rules)
        XCTAssertEqual(widths(1512, wide), [56, 500, 900])
        XCTAssertEqual(widths(2000, wide)[0], 280)
        XCTAssertEqual(widths(2000, wide)[2], 900)
        let folded = LaneLayoutEngine.drag(lane: .leading, proposed: measure.foldAt - 1, start: [280, 896, 280], mode: wide, measure: measure, rules: rules)
        XCTAssertEqual(widths(2000, folded)[0], measure.laneFolded)
        let toggled = LaneLayoutEngine.toggleFold(lane: .leading, mode: LaneLayoutEngine.toggleFold(lane: .leading, mode: wide))
        XCTAssertEqual(widths(2000, toggled)[0], measure.laneFolded)
        let old = try JSONDecoder().decode(LaneMode.self, from: Data(#"{"preferred":[280,0,280],"folded":[true,false,false]}"#.utf8))
        XCTAssertEqual(widths(2000, old)[0], measure.laneFolded)
        XCTAssertEqual(try JSONDecoder().decode(LaneMode.self, from: JSONEncoder().encode(wide)), wide)
    }

    func testMenuWidthSnapsToTheGrid() {
        XCTAssertEqual(MenuWidthEngine.width(fitting: 40), 168)
        XCTAssertEqual(MenuWidthEngine.width(fitting: 169), 224)
        XCTAssertEqual(MenuWidthEngine.width(fitting: 224), 224)
        XCTAssertEqual(MenuWidthEngine.width(fitting: 600), 280)
    }

    func testMenuAlignsByPositionInTheLane() {
        let lanes = LaneWidths(leading: 280, center: 896, trailing: 280)
        func left(_ anchor: Double, _ anchorWidth: Double, _ width: Double) -> Double {
            MenuAlignEngine.left(anchor: anchor, anchorWidth: anchorWidth, width: width, lanes: lanes, measure: measure, windowWidth: 1512)
        }
        XCTAssertEqual(left(40, 28, 224), 40)
        XCTAssertEqual(left(260, 28, 224), 64)
        XCTAssertEqual(left(320, 28, 168), 320)
        XCTAssertEqual(left(1180, 28, 224), 980)
        XCTAssertEqual(left(1220, 28, 224), 1220)
        XCTAssertEqual(left(1460, 28, 224), 1264)
        XCTAssertEqual(left(1440, 28, 280), 1216)
        XCTAssertEqual(left(4, 28, 224), 16)
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
        XCTAssertEqual(widths(1512, middleFolded)[0], 280)
        XCTAssertEqual(widths(1512, middleFolded).reduce(0, +), avail)
        let wide = LaneLayoutEngine.drag(lane: .trailing, proposed: 900, start: [280, 896, 280], mode: rest, measure: measure, rules: rules)
        XCTAssertEqual(widths(1512, wide), [56, 500, 900])
        XCTAssertEqual(wide.preferred[1], 0)
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
        model.limit("mail", mailLimits)
        XCTAssertEqual(model.widths.all, [280, 896, 280])
        model.dragLane(.trailing, translation: 0)
        model.dragLane(.trailing, translation: -620)
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
    func testHandleClickWithoutMovementKeepsTheLayout() throws {
        let model = DeskState(directory: try loadDirectory(), measure: measure, window: screen)
        var saved = 0
        model.onChange = { _ in saved += 1 }
        let before = model.laneMode("mail")
        model.dragLane(.leading, translation: 0)
        XCTAssertEqual(model.draggedLane, .leading)
        model.endLaneDrag()
        model.endLaneDrag()
        XCTAssertEqual(model.laneMode("mail"), before)
        XCTAssertFalse(model.laneDragging)
        XCTAssertEqual(saved, 0)
        model.dragLane(.leading, translation: 0)
        model.dragLane(.leading, translation: 40)
        model.dragLane(.trailing, translation: 40)
        model.endLaneDrag()
        XCTAssertEqual(model.widths.all, [320, 856, 280])
        XCTAssertEqual(saved, 1)
    }

    @MainActor
    func testHandleDownEndsMaximizeLikeTheDesign() throws {
        let model = DeskState(directory: try loadDirectory(), measure: measure, window: screen)
        let avail = LaneLayoutEngine.available(screen.width, measure)
        model.toggleMaximize(.center)
        model.dragLane(.leading, translation: 0)
        XCTAssertNil(model.laneMode("mail").maximized)
        model.dragLane(.leading, translation: 200)
        model.endLaneDrag()
        XCTAssertEqual(model.widths.all, [measure.minimum[0], avail - measure.minimum[0] - measure.laneFolded, measure.laneFolded])
    }

    @MainActor
    func testDragFromEbbKeepsTrailingFoldedUntilACardOpens() throws {
        let model = DeskState(directory: try loadDirectory(), measure: measure, window: screen)
        model.stack(empty: true, still: true)
        model.dragLane(.leading, translation: 0)
        model.dragLane(.leading, translation: 40)
        model.endLaneDrag()
        model.stack(empty: false, still: true)
        XCTAssertTrue(model.laneMode("mail").folded[2])
        XCTAssertEqual(model.widths.trailing, measure.laneFolded)
        model.reveal(.trailing)
        XCTAssertFalse(model.laneMode("mail").folded[2])
        XCTAssertEqual(model.widths.all, [320, 856, 280])
        model.stack(empty: true, still: true)
        model.reveal(.trailing)
        model.stepLane(.leading, by: measure.laneFolded)
        XCTAssertTrue(model.laneMode("mail").folded[2])
    }

    @MainActor
    func testAreaLimitsComeFromThePane() throws {
        let model = DeskState(directory: try loadDirectory(), measure: measure, window: screen)
        XCTAssertEqual(model.minimum, measure.minimum)
        model.limit("mail", mailLimits)
        XCTAssertEqual(model.minimum[0], Tokens.Size.mailLaneMinimumLeft)
        model.dragLane(.leading, translation: 0)
        model.dragLane(.leading, translation: -40)
        model.endLaneDrag()
        XCTAssertEqual(model.widths.leading, 240)
        model.dragLane(.leading, translation: 0)
        model.dragLane(.leading, translation: 200)
        model.endLaneDrag()
        XCTAssertEqual(model.widths.leading, Tokens.Size.mailLaneMaximumLeft)
        model.select("settings")
        XCTAssertEqual(model.minimum, measure.minimum)
    }

    @MainActor
    func testWidthsFollowWindowAndNeverFoldAllThree() throws {
        let model = DeskState(directory: try loadDirectory(), measure: measure, window: screen)
        XCTAssertEqual(model.widths, model.widths)
        model.resize(BlobSize(width: 1200, height: 800))
        XCTAssertEqual(model.widths.all.reduce(0, +), LaneLayoutEngine.available(1200, measure))
        var all = LaneMode(rest: measure.laneRest)
        all.folded = [true, true, true]
        XCTAssertEqual(widths(1512, all), [56, LaneLayoutEngine.available(1512, measure) - 112, 56])
    }

    @MainActor
    func testEmptyStackFoldsTrailingLaneAfterEbb() throws {
        let model = DeskState(directory: try loadDirectory(), measure: measure, window: screen)
        XCTAssertFalse(model.ebb)
        model.stack(empty: false, still: false)
        model.stack(empty: true, still: false)
        XCTAssertFalse(model.ebb)
        XCTAssertEqual(model.widths.trailing, 280)
        model.stack(empty: false, still: true)
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
    func testUnknownStackIsNoReportAndTheFirstRealValueIsTheBoot() throws {
        let model = DeskState(directory: try loadDirectory(), measure: measure, window: screen)
        model.stack(empty: nil, still: false)
        XCTAssertFalse(model.ebb)
        XCTAssertEqual(model.widths.trailing, 280)
        model.stack(empty: true, still: false)
        XCTAssertTrue(model.ebb)
        XCTAssertFalse(model.slowLane)
        XCTAssertEqual(model.widths.trailing, measure.laneFolded)
        let restored = DeskState(directory: try loadDirectory(), measure: measure, window: screen)
        restored.stack(empty: nil, still: false)
        restored.stack(empty: false, still: false)
        XCTAssertFalse(restored.ebb)
        XCTAssertFalse(restored.slowLane)
        XCTAssertEqual(restored.widths.trailing, 280)
    }

    @MainActor
    func testEmptyStackAtStartFoldsTrailingLaneAtOnce() throws {
        let model = DeskState(directory: try loadDirectory(), measure: measure, window: screen)
        model.stack(empty: true, still: false)
        XCTAssertTrue(model.ebb)
        XCTAssertFalse(model.slowLane)
        XCTAssertEqual(model.widths.trailing, measure.laneFolded)
        let filled = DeskState(directory: try loadDirectory(), measure: measure, window: screen)
        filled.stack(empty: false, still: false)
        XCTAssertFalse(filled.ebb)
        XCTAssertEqual(filled.widths.trailing, 280)
    }

    @MainActor
    func testStripDoubleClickRestsOnlyThatLane() throws {
        let model = DeskState(directory: try loadDirectory(), measure: measure, window: screen)
        model.limit("mail", mailLimits)
        var now = 100.0
        model.uptime = { now }
        func narrowTrailing() {
            model.dragLane(.trailing, translation: 0)
            model.dragLane(.trailing, translation: 40)
            model.endLaneDrag()
        }
        model.stepLane(.leading, by: -40)
        narrowTrailing()
        XCTAssertEqual(model.laneMode("mail").preferred, [240, 0, 240])
        model.toggleFold(.trailing)
        model.openStrip(.trailing)
        now += 0.3
        model.restLane(.trailing)
        XCTAssertEqual(model.laneMode("mail").preferred, [240, 0, 280])
        XCTAssertEqual(model.widths.all, [240, 936, 280])
        narrowTrailing()
        model.toggleFold(.trailing)
        model.openStrip(.trailing)
        now += 0.7
        model.restLane(.trailing)
        XCTAssertEqual(model.laneMode("mail").preferred, [240, 0, 240])
        model.toggleFold(.trailing)
        model.restLane(.trailing)
        XCTAssertEqual(model.laneMode("mail").preferred, [240, 0, 280])
        XCTAssertFalse(model.laneMode("mail").folded[2])
        model.restLane(.leading)
        XCTAssertEqual(model.laneMode("mail").preferred, [240, 0, 280])
    }

    @MainActor
    func testStripDoubleClickOpensTheMiddleWhenNoOtherSideLaneIsOpen() throws {
        let model = DeskState(directory: try loadDirectory(), measure: measure, window: screen)
        model.toggleFold(.center)
        model.toggleMaximize(.leading)
        model.restLane(.trailing)
        XCTAssertNil(model.laneMode("mail").maximized)
        XCTAssertEqual(model.laneMode("mail").folded, [false, false, false])
        let other = DeskState(directory: try loadDirectory(), measure: measure, window: screen)
        other.toggleFold(.center)
        other.toggleFold(.leading)
        other.toggleFold(.trailing)
        other.restLane(.leading)
        XCTAssertEqual(other.laneMode("mail").folded, [false, true, true])
    }

    @MainActor
    func testUnfoldEndsMaximizeAndOpensOnlyWhatIsNeeded() throws {
        let model = DeskState(directory: try loadDirectory(), measure: measure, window: screen)
        model.toggleFold(.trailing)
        model.toggleMaximize(.center)
        model.unfold(.trailing)
        XCTAssertNil(model.laneMode("mail").maximized)
        XCTAssertFalse(model.laneMode("mail").folded[2])
        model.toggleFold(.leading)
        model.unfold(.center)
        XCTAssertEqual(model.laneMode("mail").folded, [true, false, false])
        model.unfold(.trailing)
        XCTAssertEqual(model.laneMode("mail").folded, [true, false, false])
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
        XCTAssertEqual(Icon.allCases.count, 55)
        for icon in Icon.allCases {
            XCTAssertFalse(icon.path.segments.isEmpty, icon.rawValue)
        }
        XCTAssertEqual(Icon.plus.path.segments, [.move(x: 8, y: 3), .line(x: 8, y: 13), .move(x: 3, y: 8), .line(x: 13, y: 8)])
        XCTAssertEqual(IconPath(data: "M1 1h2v3z").segments, [.move(x: 1, y: 1), .line(x: 3, y: 1), .line(x: 3, y: 4), .close])
        XCTAssertEqual(IconPath(data: "M0 0 1 1").segments, [.move(x: 0, y: 0), .line(x: 1, y: 1)])
        XCTAssertEqual(IconPath(data: "M+1 -2").segments, [.move(x: 1, y: -2)])
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

    func testLockPauseSplitsLeavingFromTheIdleStep() {
        let all = [LockPause.immediately, .oneMinute, .fiveMinutes, .fifteenMinutes]
        XCTAssertEqual(all.map(\.onLeaving), [true, false, false, false])
        XCTAssertEqual(all.map(\.idle), [60, 60, 300, 900])
        XCTAssertFalse(LockPhase.open.shut)
        XCTAssertTrue([LockPhase.locked, .touchID, .touchIDFailed, .password, .passwordWrong].allSatisfy(\.shut))
        XCTAssertEqual([LockPhase.locked, .touchID, .touchIDFailed, .password, .passwordWrong].map(\.asksPassword), [false, false, false, true, true])
    }

    @MainActor
    func testLockLocksAtLaunchOnlyWhenSwitchedOn() {
        let port = FakeUnlock()
        let shut = lockState(port, FakeClock(), on: true)
        shut.launch()
        XCTAssertEqual(shut.phase, .locked)
        XCTAssertTrue(shut.touchID)
        XCTAssertNil(shut.timer)
        let free = lockState(port, FakeClock(), on: false)
        free.launch()
        XCTAssertEqual(free.phase, .open)
        XCTAssertNil(free.timer)
    }

    @MainActor
    func testLockLocksOnlyAfterTheIdleTimeAndEachInputRestartsIt() {
        let clock = FakeClock()
        let state = lockState(FakeUnlock(), clock, pause: .oneMinute)
        clock.now = 59
        state.touch()
        XCTAssertEqual(state.phase, .open)
        clock.now = 118
        state.touch()
        XCTAssertEqual(state.phase, .open)
        clock.now = 178
        state.touch()
        XCTAssertEqual(state.phase, .locked)
        clock.now = 10_000
        state.touch()
        XCTAssertEqual(state.phase, .locked)
    }

    @MainActor
    func testLockFirstInputAfterALongSleepLocksInsteadOfRestartingTheTimer() {
        let clock = FakeClock()
        let state = lockState(FakeUnlock(), clock, pause: .fifteenMinutes)
        clock.now = 899
        state.touch()
        XCTAssertEqual(state.phase, .open)
        clock.now = 899 + 8 * 3600
        state.touch()
        XCTAssertEqual(state.phase, .locked)
    }

    @MainActor
    func testLockReturningToTheAppAfterTheIdleTimeLocksAtOnce() {
        let center = NotificationCenter()
        let clock = FakeClock()
        let state = lockState(FakeUnlock(), clock, pause: .fiveMinutes, center: center)
        clock.now = 299
        center.post(name: becameName, object: nil)
        XCTAssertEqual(state.phase, .open)
        clock.now = 300
        center.post(name: becameName, object: nil)
        XCTAssertEqual(state.phase, .locked)
    }

    @MainActor
    func testLockImmediatelyAlsoLocksAfterTheShortestIdleStep() {
        let clock = FakeClock()
        let state = lockState(FakeUnlock(), clock, pause: .immediately)
        clock.now = 59
        state.touch()
        XCTAssertEqual(state.phase, .open)
        clock.now = 118
        state.touch()
        XCTAssertEqual(state.phase, .open)
        clock.now = 178
        state.touch()
        XCTAssertEqual(state.phase, .locked)
        let waiting = FakeClock()
        let timed = lockState(FakeUnlock(), waiting, on: false, pause: .oneMinute)
        timed.configure(on: true, pause: .immediately)
        XCTAssertEqual(waiting.waits, [])
        XCTAssertNotNil(timed.timer)
    }

    @MainActor
    func testLockTimerSleepsOnlyTheRemainingPause() async {
        let clock = FakeClock()
        let state = lockState(FakeUnlock(), clock, on: false, pause: .fiveMinutes)
        state.launch()
        XCTAssertNil(state.timer)
        state.configure(on: true, pause: .fiveMinutes)
        clock.idleBudget = 2
        clock.during = {
            clock.now = 100
            state.touch()
        }
        await state.timer?.value
        await state.timer?.value
        XCTAssertEqual(state.phase, .locked)
        XCTAssertEqual(clock.waits, [300, 100])
        XCTAssertNil(state.timer)
    }

    @MainActor
    func testLockSwitchedOffNeverLocks() {
        let clock = FakeClock()
        let state = lockState(FakeUnlock(), clock, on: false, pause: .oneMinute)
        state.configure(on: true, pause: .oneMinute)
        XCTAssertNotNil(state.timer)
        state.configure(on: false, pause: .oneMinute)
        XCTAssertNil(state.timer)
        clock.now = 3600
        state.touch()
        state.resign()
        XCTAssertEqual(state.phase, .open)
    }

    @MainActor
    func testLockLocksWhenTheAppLeavesOnlyForTheImmediateChoice() {
        let waiting = lockState(FakeUnlock(), FakeClock(), on: false, pause: .oneMinute)
        waiting.configure(on: true, pause: .oneMinute)
        waiting.resign()
        XCTAssertEqual(waiting.phase, .open)
        waiting.configure(on: true, pause: .immediately)
        XCTAssertNotNil(waiting.timer)
        waiting.resign()
        XCTAssertEqual(waiting.phase, .locked)
    }

    @MainActor
    func testLockWatchesTheAppLeavingByItselfWithoutAnyWindow() {
        let center = NotificationCenter()
        let immediate = lockState(FakeUnlock(), FakeClock(), on: false, pause: .oneMinute, center: center)
        immediate.configure(on: true, pause: .immediately)
        XCTAssertEqual(immediate.phase, .open)
        center.post(name: resignedName, object: nil)
        XCTAssertEqual(immediate.phase, .locked)
        let waiting = lockState(FakeUnlock(), FakeClock(), on: true, pause: .oneMinute, center: center)
        waiting.configure(on: false, pause: .oneMinute)
        waiting.configure(on: true, pause: .oneMinute)
        center.post(name: resignedName, object: nil)
        XCTAssertEqual(waiting.phase, .open)
        let other = NotificationCenter()
        let apart = lockState(FakeUnlock(), FakeClock(), on: false, pause: .oneMinute, center: other)
        apart.configure(on: true, pause: .immediately)
        center.post(name: resignedName, object: nil)
        XCTAssertEqual(apart.phase, .open)
    }

    @MainActor
    func testLockIgnoresTheLeaveThatBelongsToTheUnlockDialog() async {
        let center = NotificationCenter()
        let clock = FakeClock()
        let state = lockState(FakeUnlock(), clock, on: true, pause: .immediately, center: center)
        state.launch()
        state.useTouchID()
        await state.pending?.value
        XCTAssertEqual(state.phase, .open)
        center.post(name: resignedName, object: nil)
        XCTAssertEqual(state.phase, .open)
        let held = state.leaving
        XCTAssertNotNil(held)
        center.post(name: becameName, object: nil)
        XCTAssertNil(state.leaving)
        await held?.value
        XCTAssertEqual(state.phase, .open)
        XCTAssertTrue(clock.waits.allSatisfy { $0 <= LockState.unlockGrace || $0 == LockPause.immediately.idle })
    }

    @MainActor
    func testLockStillLocksWhenTheAppReallyStaysAwayAfterUnlocking() async {
        let center = NotificationCenter()
        let clock = FakeClock()
        clock.budget = 1
        let state = lockState(FakeUnlock(), clock, on: true, pause: .immediately, center: center)
        state.launch()
        state.useTouchID()
        await state.pending?.value
        center.post(name: resignedName, object: nil)
        XCTAssertEqual(state.phase, .open)
        await state.leaving?.value
        XCTAssertEqual(state.phase, .locked)
        XCTAssertEqual(clock.waits.filter { $0 <= LockState.unlockGrace }, [LockState.unlockGrace])
        state.useTouchID()
        await state.pending?.value
        clock.now += LockState.unlockGrace + 1
        center.post(name: resignedName, object: nil)
        XCTAssertEqual(state.phase, .locked)
    }

    @MainActor
    func testLockHandlesALeaveDuringTheAttemptWhenItEndsAfterwards() async {
        let center = NotificationCenter()
        let clock = FakeClock()
        clock.budget = 1
        let state = lockState(FakeUnlock(), clock, on: true, pause: .immediately, center: center)
        state.launch()
        state.useTouchID()
        center.post(name: resignedName, object: nil)
        XCTAssertEqual(state.phase, .touchID)
        center.post(name: becameName, object: nil)
        await state.pending?.value
        XCTAssertEqual(state.phase, .open)
        XCTAssertNil(state.leaving)
        center.post(name: resignedName, object: nil)
        await state.pending?.value
        await state.leaving?.value
        XCTAssertEqual(state.phase, .locked)
        state.useTouchID()
        center.post(name: resignedName, object: nil)
        await state.pending?.value
        XCTAssertEqual(state.phase, .open)
        XCTAssertNotNil(state.leaving)
    }

    @MainActor
    func testLockTouchIDUnlocksAndRearms() async {
        let port = FakeUnlock()
        let state = lockState(port, FakeClock())
        state.launch()
        state.useTouchID()
        XCTAssertEqual(state.phase, .touchID)
        state.useTouchID()
        await state.pending?.value
        XCTAssertEqual(state.phase, .open)
        XCTAssertEqual(port.asked, [.touchID])
        XCTAssertNotNil(state.timer)
    }

    @MainActor
    func testLockShowsAnErrorOnlyForARefusalAndReturnsQuietlyAfterACancel() async {
        let port = FakeUnlock()
        port.outcomes = [.touchID: [.refused, .cancelled], .password: [.refused, .cancelled, .refused, .granted]]
        let state = lockState(port, FakeClock())
        state.launch()
        state.useTouchID()
        await state.pending?.value
        XCTAssertEqual(state.phase, .touchIDFailed)
        state.primary()
        XCTAssertEqual(state.phase, .touchID)
        await state.pending?.value
        XCTAssertEqual(state.phase, .locked)
        state.usePassword()
        XCTAssertEqual(state.phase, .password)
        state.primary()
        await state.pending?.value
        XCTAssertEqual(state.phase, .passwordWrong)
        state.primary()
        await state.pending?.value
        XCTAssertEqual(state.phase, .locked)
        state.usePassword()
        await state.pending?.value
        XCTAssertEqual(state.phase, .passwordWrong)
        state.usePassword()
        await state.pending?.value
        XCTAssertEqual(state.phase, .open)
        XCTAssertEqual(port.asked, [.touchID, .touchID, .password, .password, .password, .password])
    }

    @MainActor
    func testLockNeverEngagesWhereTheDeviceCannotAuthenticateTheOwner() async {
        let port = FakeUnlock()
        port.available = false
        let center = NotificationCenter()
        let clock = FakeClock()
        let state = lockState(port, clock, on: true, pause: .immediately, center: center)
        XCTAssertFalse(state.available)
        state.launch()
        XCTAssertEqual(state.phase, .open)
        state.resign()
        XCTAssertEqual(state.phase, .open)
        XCTAssertNil(state.timer)
        XCTAssertEqual(clock.waits, [])
        let timed = lockState(port, clock, on: true, pause: .oneMinute, center: center)
        timed.launch()
        XCTAssertEqual(timed.phase, .open)
        XCTAssertNil(timed.timer)
        clock.now = 3600
        timed.touch()
        XCTAssertEqual(timed.phase, .open)
        XCTAssertNil(timed.timer)
        XCTAssertEqual(clock.waits, [])
        port.available = true
        clock.now = 7200
        center.post(name: becameName, object: nil)
        XCTAssertTrue(state.available)
        XCTAssertTrue(timed.available)
        XCTAssertEqual(state.phase, .locked)
        XCTAssertEqual(timed.phase, .locked)
    }

    @MainActor
    func testLockFailedLockLeavesTheIdleClockAlone() {
        let port = FakeUnlock()
        let center = NotificationCenter()
        let clock = FakeClock()
        let state = lockState(port, clock, on: true, pause: .immediately, center: center)
        port.available = false
        clock.now = 1000
        state.resign()
        XCTAssertEqual(state.phase, .open)
        XCTAssertFalse(state.available)
        port.available = true
        clock.now = 1030
        center.post(name: becameName, object: nil)
        XCTAssertEqual(state.phase, .locked)
    }

    @MainActor
    func testLockReportsEveryChangeOfPhaseToItsWatchers() async {
        let port = FakeUnlock()
        port.outcomes = [.touchID: [.refused, .granted]]
        let state = lockState(port, FakeClock())
        let log = PhaseLog()
        state.watch { log.seen.append($0) }
        state.launch()
        state.useTouchID()
        await state.pending?.value
        state.useTouchID()
        await state.pending?.value
        XCTAssertEqual(log.seen, [.locked, .touchID, .touchIDFailed, .touchID, .open])
    }

    @MainActor
    func testLockOpensWhenThePasswordCheckReportsNoPasscodeAndStaysShutOtherwise() async {
        let port = FakeUnlock()
        port.outcomes = [.password: [.unavailable, .unavailable]]
        let state = lockState(port, FakeClock())
        state.launch()
        state.usePassword()
        await state.pending?.value
        XCTAssertEqual(state.phase, .locked)
        XCTAssertTrue(state.available)
        port.available = false
        state.usePassword()
        await state.pending?.value
        XCTAssertEqual(state.phase, .open)
        XCTAssertFalse(state.available)
    }

    @MainActor
    func testLockTouchIDFallbackAndInterruptions() async {
        let port = FakeUnlock()
        port.outcomes = [.touchID: [.fallback, .interrupted, .unavailable], .password: [.interrupted]]
        let state = lockState(port, FakeClock())
        state.launch()
        state.useTouchID()
        await state.pending?.value
        await state.pending?.value
        XCTAssertEqual(state.phase, .locked)
        XCTAssertEqual(port.asked, [.touchID, .password])
        state.backToTouchID()
        XCTAssertEqual(state.phase, .locked)
        state.useTouchID()
        await state.pending?.value
        XCTAssertEqual(state.phase, .locked)
        XCTAssertTrue(state.touchID)
        state.useTouchID()
        await state.pending?.value
        XCTAssertEqual(state.phase, .locked)
        XCTAssertFalse(state.touchID)
        state.useTouchID()
        XCTAssertEqual(state.phase, .locked)
        state.primary()
        XCTAssertEqual(state.phase, .password)
        XCTAssertEqual(port.asked, [.touchID, .password, .touchID, .touchID])
    }

    @MainActor
    func testLockIgnoresTheAnswerOfACancelledCheck() async {
        let port = FakeUnlock()
        port.outcomes = [.touchID: [.granted], .password: [.refused, .granted]]
        let state = lockState(port, FakeClock())
        state.launch()
        state.useTouchID()
        let touch = state.pending
        state.usePassword()
        XCTAssertEqual(port.cancels, 1)
        let password = state.pending
        await touch?.value
        await password?.value
        XCTAssertEqual(state.phase, .passwordWrong)
        state.usePassword()
        let second = state.pending
        state.backToTouchID()
        XCTAssertEqual(port.cancels, 2)
        await second?.value
        XCTAssertEqual(state.phase, .locked)
        XCTAssertNil(state.pending)
    }
}
