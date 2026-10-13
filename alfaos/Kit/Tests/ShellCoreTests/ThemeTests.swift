import Foundation
import XCTest
@testable import ShellCore

final class ThemeTests: XCTestCase {
    func testRealSourceHasEveryGeneratedKey() throws {
        let theme = try Fixture.theme()
        XCTAssertEqual(theme.missing, [])
        XCTAssertEqual(theme.missingText, [])
        XCTAssertEqual(Set(ThemeKey.all).count, ThemeKey.all.count)
    }

    func testAliasFollowsTheMode() throws {
        let theme = try Fixture.theme()
        XCTAssertEqual(theme.color(.colorBackgroundContent, .light), theme.color(.colorBackgroundContainer, .light))
        XCTAssertEqual(theme.color(.colorBackgroundSelected, .dark), theme.color(.colorTextPrimary, .dark))
        XCTAssertNotEqual(theme.color(.colorTextPrimary, .light), theme.color(.colorTextPrimary, .dark))
    }

    func testRemovedTokenIsMagentaAndListed() throws {
        let data = try Fixture.data("gestaltung/alfa-interface/tokens.json")
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var color = try XCTUnwrap(root["color"] as? [String: Any])
        var tokens = try XCTUnwrap(color["tokens"] as? [[String: Any]])
        tokens.removeAll { ($0["name"] as? String) == "color-line-separator" }
        color["tokens"] = tokens
        root["color"] = color
        let theme = try TokenTheme(data: JSONSerialization.data(withJSONObject: root))
        XCTAssertEqual(theme.color(.colorLineSeparator, .light), RGB.missing)
        XCTAssertEqual(theme.color(.colorLineSeparator, .dark), RGB.missing)
        XCTAssertEqual(theme.missing, [.colorLineSeparator])
    }

    func testValuesParse() throws {
        let theme = try Fixture.theme()
        XCTAssertEqual(theme.length(.componentLaneRestingWidth), 300)
        XCTAssertEqual(theme.duration(.motionDurationChange), 0.2, accuracy: 1e-9)
        XCTAssertEqual(theme.curve(.motionCurveStandard), CubicBezier(x1: 0.2, y1: 0.8, x2: 0.2, y2: 1))
        XCTAssertEqual(theme.color(.colorBackgroundOverlay, .light), RGB(0, 0, 0, 0.2))
        let style = try XCTUnwrap(theme.textStyle(.name))
        XCTAssertEqual(style.size, 13)
        XCTAssertEqual(style.weight, 500)
        XCTAssertEqual(style.tracking, 0.065, accuracy: 1e-9)
    }

    func testShadowLayersAndContour() throws {
        let theme = try Fixture.theme()
        let floating = theme.shadow(.shadowFloating, .light)
        XCTAssertEqual(floating.count, 2)
        XCTAssertTrue(floating[0].isContour)
        XCTAssertEqual(floating[1].blur, 24)
        XCTAssertEqual(theme.shadow(.shadowInset, .light), [])
        XCTAssertTrue(theme.shadow(.shadowInsetHover, .light)[0].inset)
        XCTAssertEqual(theme.shadow("shadow-unknown", .light).first?.color, RGB.missing)
    }

    func testBrokenAliasesAreMagenta() throws {
        let json = """
        {"color":{"themes":[{"id":"light"}],"tokens":[
        {"name":"a","value":"{b}"},{"name":"b","value":"{a}"},{"name":"c","value":"{nowhere}"},{"name":"d","value":"nonsense"}]},
        "type":{"families":{},"groups":[]}}
        """
        let theme = try TokenTheme(data: Data(json.utf8))
        for name in ["a", "b", "c", "d"] {
            XCTAssertEqual(theme.color(ThemeKey(name), .light), RGB.missing, name)
        }
    }

    func testShellMeasuresComeFromTheDataFile() throws {
        let metrics = try Fixture.metrics()
        XCTAssertEqual(metrics.shadowBlurFactor, 0.5)
        for key in ShellMeasure.allCases {
            XCTAssertGreaterThan(metrics.measure(key), 0, key.rawValue)
        }
    }

    func testMissingMeasureFailsLoading() throws {
        let json = """
        {"lane-min":1,"center-min":1,"blob-width":1,"blob-throw":1,"shadow-blur-factor":1,"assistant-width":1,
        "window-min-width":1,"window-min-height":1,"measures":{"face-eye-gap":5}}
        """
        XCTAssertThrowsError(try ShellMetrics(data: Data(json.utf8)))
    }
}
