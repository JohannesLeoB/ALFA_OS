import Foundation
import XCTest
@testable import ShellCore

final class LayoutTests: XCTestCase {
    func testRestingWidthsOnTheLargeScreen() throws {
        let g = try Fixture.geometry()
        let widths = LaneLayout.widths(windowWidth: 1512, state: LaneState(rest: g.laneRest), geometry: g)
        XCTAssertEqual([widths.leading, widths.center, widths.trailing], [280, 896, 280])
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
    // Nachbauten offener Fehler (BUG-1-x): grün, solange der Fehler besteht (XCTExpectFailure), rot sobald er behoben ist.

    /// BUG-1-1 und BUG-1-2: „Aufklappen“ lässt eine vom Fenster oder durch „Groß“ der Mitte gefaltete Bahn gefaltet.
    func testUnfoldOnAFoldedLaneUnfoldsIt() throws {
        let g = try Fixture.geometry()
        let state = LaneState(rest: g.laneRest)
        let before = LaneLayout.widths(windowWidth: g.windowMin.width, state: state, geometry: g)
        XCTAssertEqual(before.trailing, g.laneFolded, "Voraussetzung: rechte Bahn ist im Mindestfenster bereits gefaltet")
        XCTAssertFalse(state.trailingFolded, "Voraussetzung: der Zustand weiß nichts davon")
        let maximized = LaneLayout.toggleMaximize(lane: .center, state: LaneState(rest: g.laneRest))
        let folded = LaneLayout.widths(windowWidth: 1512, state: maximized, geometry: g)
        XCTAssertEqual(folded.leading, g.laneFolded)
    }

    /// BUG-1-3 und BUG-1-4: Ein bloßer Klick auf den Griff (DragGesture mit minimumDistance 0) schreibt die vom Fenster
    /// verengte oder gefaltete Breite dauerhaft fest. HandleView.swift:28-34 übergibt `widths.width(lane)` als `proposed`.
    func testPlainClickOnTheHandleKeepsTheStoredWidth() throws {
        let g = try Fixture.geometry()
        var narrowed = LaneState(rest: g.laneRest)
        let narrow = LaneLayout.widths(windowWidth: 1024, state: narrowed, geometry: g)
        XCTAssertLessThan(narrow.leading, g.laneRest, "Voraussetzung: links ist bei 1024 verengt")
        narrowed = LaneLayout.drag(lane: .leading, proposed: narrow.leading, state: narrowed, windowWidth: 1024, geometry: g)
        var foldedState = LaneState(rest: g.laneRest)
        let small = LaneLayout.widths(windowWidth: g.windowMin.width, state: foldedState, geometry: g)
        XCTAssertEqual(small.trailing, g.laneFolded)
        foldedState = LaneLayout.drag(lane: .trailing, proposed: small.trailing, state: foldedState, windowWidth: g.windowMin.width, geometry: g)
    }

    /// BUG-1-5: Gespeicherte Breite wird beim Laden nicht an das heutige Höchstmaß gebunden.
    /// Das Token component-lane-leading-max-width wurde am 11.10.2026 von 420 auf 380 gesenkt (Issue 18, 17:15).
    func testStoredWidthAboveCurrentMaximumIsClamped() throws {
        let g = try Fixture.geometry()
        var state = LaneState(rest: g.laneRest)
        state.leading = 420
        let widths = LaneLayout.widths(windowWidth: 1512, state: state, geometry: g)
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
    /// BUG-1-6 und BUG-1-7: Lage und Loslassen rechnen mit der ruhenden Breite (56), der wache Blob ist 124 breit
    /// (BlobView.swift:12 `model.blobWidth`, :18 `$0.x - width / 2`): er ragt am Rand über das Fenster und springt beim Loslassen um 34.

    /// BUG-1-8: Der Blob lässt sich oben rechts auf die Pille legen und verdeckt sie.
    /// Pillenmaße wie in ShellView.swift:55-58 und BlobView.swift:100-107 aus Token gerechnet (Spiegelrechnung, dort nicht in ShellCore).
    func testBlobCannotCoverThePill() throws {
        let g = try Fixture.geometry()
        let theme = try Fixture.theme()
        let pillWidth = theme.length(.spaceXs) * 3 + theme.length(.sizeControlM) * 2
        let origin = BlobPlacement(edge: .top, offset: 10_000).origin(window: Fixture.screen, geometry: g)
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

    private func model(snapshot: ShellSnapshot? = nil) throws -> ShellModel {
        ShellModel(directory: try Fixture.directory(), geometry: try Fixture.geometry(), window: Fixture.screen, snapshot: snapshot)
    }

    /// BUG-1-9: Die Gruppe des aktuellen Bereichs lässt sich nicht zuklappen (isGroupOpen: `|| current?.group == group.id`).
    func testGroupOfCurrentAreaCanBeCollapsed() throws {
        let shell = try model()
        let group = try XCTUnwrap(shell.directory.groups.first { $0.contains(shell.currentID) })
        XCTAssertTrue(shell.isGroupOpen(group))
        shell.toggleGroup(group)
    }

    /// BUG-1-10: Ein Klick auf den Gruppenkopf während der Suche löscht die gespeicherte Öffnung der Gruppe.
    func testGroupHeaderClickDuringSearchKeepsStoredOpenState() throws {
        let g = try Fixture.geometry()
        let snapshot = ShellSnapshot(currentID: "mail", lanes: [:], blob: BlobPlacement.home(geometry: g), openGroups: ["core"])
        let shell = try model(snapshot: snapshot)
        let core = try XCTUnwrap(shell.directory.groups.first { $0.id == "core" })
        shell.query = "e"
        shell.toggleGroup(core)
        shell.query = ""
    }

    /// BUG-1-11: Ist die gemerkte Bereichskennung unbekannt, wird der ganze gemerkte Zustand verworfen
    /// (ShellModel.init: `valid` nil für Bahnen, Blob und Gruppen zugleich).

    func testMaximizingAMaximizedLaneTakesTheMaximizeBack() throws {
        let g = try Fixture.geometry()
        let state = LaneState(rest: g.laneRest)
        let once = LaneLayout.toggleMaximize(lane: .center, state: state)
        XCTAssertEqual(once.maximized, .center)
        XCTAssertNil(LaneLayout.toggleMaximize(lane: .center, state: once).maximized)
    }
}
