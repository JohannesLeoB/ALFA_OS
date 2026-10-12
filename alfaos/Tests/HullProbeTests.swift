import AppKit
import ShellCore
import SwiftUI
import XCTest

@MainActor
final class HullProbeTests: XCTestCase {
    private func resources() throws -> ShellResources {
        try ShellResources(bundle: Bundle(for: HullProbeTests.self))
    }

    private func outputFolder() throws -> URL {
        let path = ProcessInfo.processInfo.environment["ALFA_OS_PROBE_OUT"] ?? NSTemporaryDirectory() + "alfa-os-probe"
        let url = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func render(name: String, menuOpen: Bool, assistantOpen: Bool = false, dark: Bool = false, mailHost: MailHost? = nil) throws -> NSBitmapImageRep {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let resources = try resources()
        let screen = Size(width: 1512, height: 982)
        let model = ShellModel(directory: resources.directory, geometry: resources.geometry, window: screen)
        if menuOpen { model.toggleMenu() }
        if assistantOpen { model.toggleAssistant() }
        let frame = NSRect(x: -20000, y: 0, width: screen.width, height: screen.height)
        let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.alphaValue = 0
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        let host = NSHostingView(rootView: ShellView(resources: resources, bundle: Bundle(for: HullProbeTests.self), model: model).environment(\.mailInboxLive, false).environment(\.mailHost, mailHost))
        host.frame = NSRect(origin: .zero, size: frame.size)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        host.layoutSubtreeIfNeeded()
        let scale = 2
        let rep = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(screen.width) * scale,
            pixelsHigh: Int(screen.height) * scale,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ))
        rep.size = frame.size
        host.cacheDisplay(in: host.bounds, to: rep)
        let png = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        try png.write(to: outputFolder().appendingPathComponent(name + "@2x.png"))
        window.close()
        return rep
    }

    private func inkCount(_ rep: NSBitmapImageRep) -> Int {
        guard let data = rep.bitmapData else { return 0 }
        var count = 0
        let total = rep.pixelsWide * rep.pixelsHigh
        for index in 0..<total where data[index * 4] < 250 { count += 1 }
        return count
    }

    func testHullRendersClosedAndOpen() throws {
        let closed = try render(name: "huelle-closed", menuOpen: false)
        let open = try render(name: "huelle-open", menuOpen: true)
        XCTAssertEqual(closed.pixelsWide, 3024)
        XCTAssertEqual(closed.pixelsHigh, 1964)
        XCTAssertGreaterThan(inkCount(closed), 0)
        XCTAssertGreaterThan(inkCount(open), inkCount(closed))
    }

    func testAssistantAndDarkRender() throws {
        let assistant = try render(name: "huelle-assistant", menuOpen: false, assistantOpen: true)
        let dark = try render(name: "huelle-dark", menuOpen: false, dark: true)
        let darkOpen = try render(name: "huelle-dark-open", menuOpen: true, dark: true)
        XCTAssertGreaterThan(inkCount(assistant), 0)
        XCTAssertGreaterThan(inkCount(dark), 0)
        XCTAssertGreaterThan(inkCount(darkOpen), 0)
    }

    func testMailStaysIdleWhenNotLive() throws {
        let host = MailHost()
        _ = try render(name: "huelle-mail-idle", menuOpen: false, mailHost: host)
        XCTAssertTrue(host.isIdle)
    }
}
