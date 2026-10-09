import SwiftUI
import AppKit
import WebKit
import BoardModel

/// Catches scroll events over its area and reports them with the pointer position in canvas points.
/// It takes no clicks: the view under it keeps all other input. A scroll over the canvas goes to the canvas,
/// except where `keeps` says a view on top needs it, or a scroll view or web view under the pointer can move.
struct ScrollCatcher: NSViewRepresentable {
    /// True when a view on top of the canvas at this point must get the scroll.
    var keeps: (CGPoint) -> Bool
    var onScroll: (ScrollInput) -> Void

    func makeNSView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.keeps = keeps
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ view: CatcherView, context: Context) {
        view.keeps = keeps
        view.onScroll = onScroll
    }

    static func dismantleNSView(_ view: CatcherView, coordinator: ()) {
        view.stopListening()
    }

    final class CatcherView: NSView {
        var keeps: ((CGPoint) -> Bool)?
        var onScroll: ((ScrollInput) -> Void)?
        private var monitor: Any?

        /// The top left is the origin, as in SwiftUI.
        override var isFlipped: Bool { true }

        /// No hit: clicks and hovers pass through to the views below.
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopListening()
            if window != nil { startListening() }
        }

        private func startListening() {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                let carried = CarriedEvent(event: event)
                let consumed = MainActor.assumeIsolated { self?.handle(carried.event) ?? false }
                return consumed ? nil : event
            }
        }

        func stopListening() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        /// The monitor runs on the main thread; the box lets the event cross into the main actor.
        private struct CarriedEvent: @unchecked Sendable { let event: NSEvent }

        /// True when a scroll view or web view under the pointer can move, so it gets the scroll wheel.
        /// A scroll view that fits its content does not take it: the canvas zooms and pans as before.
        private func scrollsContent(at location: NSPoint) -> Bool {
            // The frame view of the window is the superview of the content view; hit tests take its coordinates.
            guard let frame = window?.contentView?.superview else { return false }
            guard let hit = frame.hitTest(frame.convert(location, from: nil)) else { return false }
            var view: NSView? = hit
            while let current = view {
                if let scroll = current as? NSScrollView, Self.canMove(scroll) { return true }
                if current is WKWebView { return true }
                view = current.superview
            }
            return false
        }

        /// True when the content of the scroll view is larger than what it shows, in one direction at least.
        static func canMove(_ scroll: NSScrollView) -> Bool {
            guard let document = scroll.documentView else { return false }
            let shown = scroll.contentView.bounds.size
            return document.frame.width > shown.width + 0.5 || document.frame.height > shown.height + 0.5
        }

        /// True when the event was a scroll over this view and was passed on.
        private func handle(_ event: NSEvent) -> Bool {
            guard event.window === window, window?.attachedSheet == nil else { return false }
            let point = convert(event.locationInWindow, from: nil)
            guard bounds.contains(point), keeps?(point) != true else { return false }
            guard !scrollsContent(at: event.locationInWindow) else { return false }
            onScroll?(ScrollInput(deltaX: event.scrollingDeltaX, deltaY: event.scrollingDeltaY,
                                  isPrecise: event.hasPreciseScrollingDeltas,
                                  zooms: event.modifierFlags.contains(.command),
                                  x: point.x, y: point.y))
            return true
        }
    }
}
