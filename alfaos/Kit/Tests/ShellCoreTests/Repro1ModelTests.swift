import Foundation
import XCTest
@testable import ShellCore

@MainActor
final class Repro1ModelTests: XCTestCase {
    private func model(snapshot: ShellSnapshot? = nil) throws -> ShellModel {
        ShellModel(directory: try Fixture.directory(), geometry: try Fixture.geometry(), window: Fixture.screen, snapshot: snapshot)
    }

    /// BUG-1-9: Die Gruppe des aktuellen Bereichs lässt sich nicht zuklappen (isGroupOpen: `|| current?.group == group.id`).
    func testBug1_9_groupOfCurrentAreaCannotBeCollapsed() throws {
        let shell = try model()
        let group = try XCTUnwrap(shell.directory.groups.first { $0.id == shell.current?.group })
        XCTAssertTrue(shell.isGroupOpen(group))
        shell.toggleGroup(group)
        XCTExpectFailure("BUG-1-9: Klick auf den Kopf der Gruppe „Kommunikation“ (minus) bei Mail ändert nichts") {
            XCTAssertFalse(shell.isGroupOpen(group))
        }
    }

    /// BUG-1-10: Ein Klick auf den Gruppenkopf während der Suche löscht die gespeicherte Öffnung der Gruppe.
    func testBug1_10_groupHeaderClickDuringSearchEditsStoredOpenState() throws {
        let g = try Fixture.geometry()
        let snapshot = ShellSnapshot(currentID: "mail", lanes: [:], blob: BlobPlacement.home(geometry: g), openGroups: ["core"])
        let shell = try model(snapshot: snapshot)
        let core = try XCTUnwrap(shell.directory.groups.first { $0.id == "core" })
        shell.query = "e"
        shell.toggleGroup(core)
        shell.query = ""
        XCTExpectFailure("BUG-1-10: nach der Suche ist „Kern“ zu, obwohl er vorher offen war und der Klick nur die Suchansicht betraf") {
            XCTAssertTrue(shell.isGroupOpen(core))
        }
    }

    /// BUG-1-11: Ist die gemerkte Bereichskennung unbekannt, wird der ganze gemerkte Zustand verworfen
    /// (ShellModel.init: `valid` nil für Bahnen, Blob und Gruppen zugleich).
    func testBug1_11_unknownCurrentIDDiscardsBlobAndLanes() throws {
        let g = try Fixture.geometry()
        var state = LaneState(rest: g.laneRest)
        state.leading = 260
        let snapshot = ShellSnapshot(currentID: "removed-app", lanes: ["mail": state], blob: BlobPlacement(edge: .trailing, offset: 300), openGroups: ["core"])
        let shell = try model(snapshot: snapshot)
        XCTExpectFailure("BUG-1-11: Blob springt an den Ursprung, Mail-Breite 260 und offene Gruppe „Kern“ sind weg, weil nur der Bereich unbekannt ist") {
            XCTAssertEqual(shell.blob.edge, .trailing)
            XCTAssertEqual(shell.laneState("mail").leading, 260)
        }
    }

    /// BUG-1-12: Ein Bereich, dessen Gruppe in apps.json fehlt, ist wählbar (select), steht aber in keiner Menüzeile.
    func testBug1_12_appWithUnknownGroupIsUnreachableInTheMenu() throws {
        let lanes = AppLanes(leadingKey: "l", centerKey: "c", trailingKey: "t")
        let directory = AppDirectory(
            groups: [AppGroup(id: "a", titleKey: "group.a")],
            apps: [AppEntry(id: "x", group: "missing", titleKey: "app.x", symbol: "s", lanes: lanes)]
        )
        let listed = directory.rows(matching: "", title: { $0 }).flatMap(\.apps).map(\.id)
        XCTExpectFailure("BUG-1-12: rows() lässt den Bereich „x“ stillschweigend weg; keine Prüfung beim Laden") {
            XCTAssertEqual(listed, ["x"])
        }
    }
}
