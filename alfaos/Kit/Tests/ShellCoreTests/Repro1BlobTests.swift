import Foundation
import XCTest
@testable import ShellCore

final class Repro1BlobTests: XCTestCase {
    /// BUG-1-6: Die Lage klemmt mit der ruhenden Breite (56). Wach ist der Blob 124 breit (BlobView.swift:12 `model.blobWidth`)
    /// und ragt am oberen und unteren Rand rechts über den Fensterrand.
    func testBug1_6_awakeBlobAtTopEdgeOverflowsTheWindow() throws {
        let g = try Fixture.geometry()
        let placement = BlobPlacement(edge: .top, offset: 10_000)
        let origin = placement.origin(window: Fixture.screen, geometry: g)
        XCTAssertEqual(g.blobAwakeWidth, 124, "Voraussetzung: Token component-blob-awake-width")
        XCTExpectFailure("BUG-1-6: x = 1440, wach reicht der Blob bis 1564, das Fenster endet bei 1512, der Rand bei 1496") {
            XCTAssertLessThanOrEqual(origin.x + g.blobAwakeWidth, Fixture.screen.width - g.margin)
        }
    }

    /// BUG-1-7: Beim Loslassen rechnet `settle` mit der ruhenden Breite, gezeichnet wird beim Ziehen mit der wachen
    /// (BlobView.swift:18 `$0.x - width / 2`, width = 124). Der Blob springt beim Loslassen um (124 - 56) / 2 = 34 nach rechts.
    func testBug1_7_blobJumpsWhenDropped() throws {
        let g = try Fixture.geometry()
        let drop = Point(x: 700, y: 20)
        let placement = BlobPlacement.settle(dropAt: drop, velocity: Point(x: 0, y: 0), window: Fixture.screen, geometry: g)
        let after = placement.origin(window: Fixture.screen, geometry: g)
        let centerAfter = after.x + g.blobAwakeWidth / 2
        XCTExpectFailure("BUG-1-7: Mitte vor dem Loslassen 700, danach 734 (wach gezeichnet)") {
            XCTAssertEqual(centerAfter, drop.x, accuracy: 0.5)
        }
    }

    /// BUG-1-8: Der Blob lässt sich oben rechts auf die Pille legen und verdeckt sie.
    /// Pillenmaße wie in ShellView.swift:55-58 und BlobView.swift:100-107 aus Token gerechnet (Spiegelrechnung, dort nicht in ShellCore).
    func testBug1_8_blobCanCoverThePill() throws {
        let g = try Fixture.geometry()
        let theme = try Fixture.theme()
        let pillWidth = theme.length(.spaceXs) * 3 + theme.length(.sizeControlM) * 2
        let pillLeft = Fixture.screen.width - g.margin - theme.length(.spaceS) - pillWidth
        let origin = BlobPlacement(edge: .top, offset: 10_000).origin(window: Fixture.screen, geometry: g)
        XCTExpectFailure("BUG-1-8: Blob (x 1440 bis 1496, y 12) liegt über der Pille (x 1420 bis 1488, y 12)") {
            XCTAssertLessThanOrEqual(origin.x + g.blobWidth, pillLeft)
        }
    }
}
