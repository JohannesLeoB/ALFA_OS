import SwiftUI
import AppKit
import BoardModel

/// Catches scroll events over its area and reports them with the pointer position in canvas points.
/// It takes no clicks: the view under it keeps all other input. A scroll over the canvas goes to the canvas,
/// except where `keeps` says a view on top needs it.
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

        /// True when the event was a scroll over this view and was passed on.
        private func handle(_ event: NSEvent) -> Bool {
            guard event.window === window, window?.attachedSheet == nil else { return false }
            let point = convert(event.locationInWindow, from: nil)
            guard bounds.contains(point), keeps?(point) != true else { return false }
            onScroll?(ScrollInput(deltaX: event.scrollingDeltaX, deltaY: event.scrollingDeltaY,
                                  isPrecise: event.hasPreciseScrollingDeltas,
                                  zooms: event.modifierFlags.contains(.command),
                                  x: point.x, y: point.y))
            return true
        }
    }
}
