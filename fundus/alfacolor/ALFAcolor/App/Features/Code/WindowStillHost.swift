import AppKit
import CodePlayer
import SwiftUI
import WebKit

/// Draws a card page in a hidden window of the preview width, so the page lays out at the width of its still.
/// Scripts and animations get a short settle time before the export.
@available(macOS 26.0, *)
@MainActor
struct WindowStillHost: StillHost {
    /// Time for layout and for the first frames to draw. Animations that run per frame need this long to show their
    /// text: at 300 ms a probe still held 60 % of the ink it had at 1.5 s, and 3 s added nothing.
    static let settle = Duration.milliseconds(1500)
    /// Jumps CSS and Web Animations to their end, so that the still shows the finished state.
    static let finishAnimations = "document.getAnimations().forEach(function(a){try{a.finish()}catch(e){}})"

    func export(_ page: WebPage, width: Double) async throws -> Data {
        let height = (width * 0.75).rounded()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.alphaValue = 0
        window.ignoresMouseEvents = true
        window.contentView = NSHostingView(rootView: WebView(page).frame(width: CGFloat(width), height: CGFloat(height)))
        window.orderBack(nil)
        defer { window.close() }
        try await Task.sleep(for: Self.settle)
        _ = try? await page.callJavaScript(Self.finishAnimations)
        try await Task.sleep(for: .milliseconds(100))
        return try await page.exported(as: .image(snapshotWidth: width))
    }
}
