import Foundation
import XCTest
@testable import ShellCore

final class RoundTripTests: XCTestCase {
    func testLaneMaxComesFromTheWorkspaceToken() throws {
        let theme = try Fixture.theme()
        let geometry = ShellGeometry(theme: theme, metrics: try Fixture.metrics())
        XCTAssertEqual(geometry.laneMax, theme.length(.componentLaneLeadingMaxWidth))
    }

    func testChangedTokenReachesTheGeometry() throws {
        let data = try Fixture.data("gestaltung/alfa-interface/tokens.json")
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var layout = try XCTUnwrap(root["layout"] as? [String: Any])
        var tokens = try XCTUnwrap(layout["tokens"] as? [[String: Any]])
        let index = try XCTUnwrap(tokens.firstIndex { ($0["name"] as? String) == "component-lane-leading-max-width" })
        tokens[index]["value"] = "333px"
        layout["tokens"] = tokens
        root["layout"] = layout
        let theme = try TokenTheme(data: JSONSerialization.data(withJSONObject: root))
        let geometry = ShellGeometry(theme: theme, metrics: try Fixture.metrics())
        XCTAssertEqual(geometry.laneMax, 333)
    }
}
