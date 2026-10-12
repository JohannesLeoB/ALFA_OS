import Foundation
import XCTest
@testable import ShellCore

/// Nachbau je Fehler. Jeder Test ist grün, solange der Fehler besteht (XCTExpectFailure),
/// und schlägt an, sobald der Fehler behoben ist. Nichts wird hier behoben.
final class Repro1LaneTests: XCTestCase {
    /// BUG-1-1: Ein vom Fenster selbst gefaltetes Band lässt sich mit „Aufklappen“ nicht öffnen.
    func testBug1_1_unfoldButtonOnLayoutFoldedLaneDoesNothing() throws {
        let g = try Fixture.geometry()
        let state = LaneState(rest: g.laneRest)
        let before = LaneLayout.widths(windowWidth: g.windowMin.width, state: state, geometry: g)
        XCTAssertEqual(before.trailing, g.laneFolded, "Voraussetzung: rechte Bahn ist im Mindestfenster bereits gefaltet")
        XCTAssertFalse(state.trailingFolded, "Voraussetzung: der Zustand weiß nichts davon")
        let after = LaneLayout.widths(windowWidth: g.windowMin.width, state: LaneLayout.toggleFold(lane: .trailing, state: state, geometry: g), geometry: g)
        XCTExpectFailure("BUG-1-1: Klick auf Aufklappen (plus) an der vom Fenster gefalteten rechten Bahn setzt trailingFolded auf true; sichtbar bleibt sie gefaltet") {
            XCTAssertGreaterThan(after.trailing, g.laneFolded)
        }
    }

    /// BUG-1-2: Ist eine Seitenbahn durch „Groß“ der Mitte gefaltet, bleibt sie nach „Aufklappen“ gefaltet.
    func testBug1_2_unfoldAfterCenterMaximizeLeavesLaneFolded() throws {
        let g = try Fixture.geometry()
        let maximized = LaneLayout.toggleMaximize(lane: .center, state: LaneState(rest: g.laneRest))
        let folded = LaneLayout.widths(windowWidth: 1512, state: maximized, geometry: g)
        XCTAssertEqual(folded.leading, g.laneFolded)
        let after = LaneLayout.widths(windowWidth: 1512, state: LaneLayout.toggleFold(lane: .leading, state: maximized, geometry: g), geometry: g)
        XCTExpectFailure("BUG-1-2: Aufklappen an der durch Groß gefalteten linken Bahn hebt Groß auf, setzt aber leadingFolded auf true; links bleibt 56, rechts springt auf 300") {
            XCTAssertGreaterThan(after.leading, g.laneFolded)
        }
    }

    /// BUG-1-3: Ein bloßer Klick auf den Griff (DragGesture mit minimumDistance 0) schreibt die vom Fenster
    /// verengte Breite als gespeicherte Breite fest. HandleView.swift:28-34 übergibt `widths.width(lane)` als `proposed`.
    func testBug1_3_plainClickOnHandleOverwritesStoredWidthWithNarrowedWidth() throws {
        let g = try Fixture.geometry()
        var state = LaneState(rest: g.laneRest)
        let narrow = LaneLayout.widths(windowWidth: 1024, state: state, geometry: g)
        XCTAssertLessThan(narrow.leading, g.laneRest, "Voraussetzung: links ist bei 1024 verengt")
        state = LaneLayout.drag(lane: .leading, proposed: narrow.leading, state: state, windowWidth: 1024, geometry: g)
        let wide = LaneLayout.widths(windowWidth: 1512, state: state, geometry: g)
        XCTExpectFailure("BUG-1-3: Klick ohne Ziehen speichert 248 statt 300; im großen Fenster bleibt die linke Bahn 248") {
            XCTAssertEqual(wide.leading, g.laneRest)
        }
    }

    /// BUG-1-4: Klick auf den Griff einer vom Fenster gefalteten Bahn setzt die Faltung dauerhaft.
    func testBug1_4_plainClickOnHandleOfLayoutFoldedLanePersistsFold() throws {
        let g = try Fixture.geometry()
        var state = LaneState(rest: g.laneRest)
        let small = LaneLayout.widths(windowWidth: g.windowMin.width, state: state, geometry: g)
        XCTAssertEqual(small.trailing, g.laneFolded)
        state = LaneLayout.drag(lane: .trailing, proposed: small.trailing, state: state, windowWidth: g.windowMin.width, geometry: g)
        let wide = LaneLayout.widths(windowWidth: 1512, state: state, geometry: g)
        XCTExpectFailure("BUG-1-4: Klick auf den Griff der gefalteten rechten Bahn setzt trailingFolded; im großen Fenster bleibt sie bei 56 statt 300") {
            XCTAssertEqual(wide.trailing, g.laneRest)
        }
    }

    /// BUG-1-5: Gespeicherte Breite wird beim Laden nicht an das heutige Höchstmaß gebunden.
    /// Das Token component-lane-leading-max-width wurde am 11.10.2026 von 420 auf 380 gesenkt (Issue 18, 17:15).
    func testBug1_5_storedWidthAboveCurrentMaximumIsKept() throws {
        let g = try Fixture.geometry()
        var state = LaneState(rest: g.laneRest)
        state.leading = 420
        let widths = LaneLayout.widths(windowWidth: 1512, state: state, geometry: g)
        XCTExpectFailure("BUG-1-5: gespeicherte 420 bleiben 420, das Höchstmaß ist 380") {
            XCTAssertLessThanOrEqual(widths.leading, g.laneMax)
        }
    }
}
