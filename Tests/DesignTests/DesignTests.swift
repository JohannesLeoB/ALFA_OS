import Foundation
import XCTest
import Design

final class DesignTests: XCTestCase {
    func testGeneratedFilesMatchGenerator() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["-I", root.appendingPathComponent("utils/generate_tokens.py").path, "--check"]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
    }

    func testSizesAndRadiiFromMaster() {
        XCTAssertEqual(Tokens.Size.edge, 16)
        XCTAssertEqual(Tokens.Size.gutter, 12)
        XCTAssertEqual(Tokens.Size.laneRestWidth, 280)
        XCTAssertEqual(Tokens.Radius.lane, 20)
        XCTAssertEqual(Tokens.Radius.card, 20)
        XCTAssertEqual(Tokens.Component.laneRadius, Tokens.Radius.lane)
        XCTAssertEqual(Tokens.Component.laneEdge, Tokens.Size.edge)
    }

    func testMotionFromMaster() {
        XCTAssertEqual(Tokens.Duration.hover, 0.16, accuracy: 1e-9)
        XCTAssertEqual(Tokens.Duration.lane, 0.26, accuracy: 1e-9)
        XCTAssertEqual([Tokens.Easing.standard.x1, Tokens.Easing.standard.y1, Tokens.Easing.standard.x2, Tokens.Easing.standard.y2], [0.2, 0.8, 0.2, 1])
        XCTAssertEqual(Tokens.Weight.regular, 400)
        XCTAssertEqual(Tokens.Count.stackMaxCards, 6)
        XCTAssertEqual(Tokens.Opacity.ringOnColor, 0.3, accuracy: 1e-9)
    }

    func testColorsFromMaster() {
        XCTAssertEqual(Colors.light.ground, ColorValue(1, 1, 1, 1))
        XCTAssertEqual(Colors.light.ink, ColorValue(0.0902, 0.0902, 0.0902, 1))
        XCTAssertEqual(Colors.dark.ground, ColorValue(0.051, 0.051, 0.051, 1))
        XCTAssertEqual(Moods.light.coral, ColorValue(0.9765, 0.3608, 0.2941, 1))
        XCTAssertEqual(Tokens.stackLight.first?.surface, ColorValue(0.9608, 0.9608, 0.9608, 1))
    }

    func testInkSetReadsColorRoles() {
        XCTAssertEqual(Colors.light[keyPath: InkSet.of(false).primary], Colors.light.ink)
        XCTAssertEqual(Colors.light[keyPath: InkSet.of(false).line], Colors.light.lineStrong)
        XCTAssertEqual(Colors.dark[keyPath: InkSet.of(true).primary], Colors.dark.onInverse)
        XCTAssertEqual(Colors.dark[keyPath: InkSet.inverse.secondary], Colors.dark.onInverseSecondary)
    }

    func testShadowGeometry() {
        let segment = Shadows.light.segment
        XCTAssertEqual(segment.count, 1)
        XCTAssertEqual(segment[0].blur, 2)
        XCTAssertEqual(segment[0].color, ColorValue(0, 0, 0, 0.12))
        XCTAssertFalse(segment[0].isContour)
        XCTAssertEqual(ShadowLayer.reach(Shadows.overviewHoverLight), 42)
        XCTAssertEqual(ShadowLayer.reach([]), 0)
    }

    func testAppearanceKeys() {
        XCTAssertEqual(AppearanceChoice.allCases.map(\.key), ["settings.appearance.light", "settings.appearance.dark", "settings.appearance.system"])
    }
}
