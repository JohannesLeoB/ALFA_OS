import SwiftUI
import AppKit
import BoardModel

/// Catches scroll events over its area and reports them with the pointer position in canvas points.
/// It takes no clicks: the view under it keeps all other input. The scroll goes to the canvas
/// and no further, so a scroll over the canvas never moves another view.
struct ScrollCatcher: NSViewRepresentable {
    var onScroll: (ScrollInput) -> Void

    func makeNSView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ view: CatcherView, context: Context) {
        view.onScroll = onScroll
    }

    static func dismantleNSView(_ view: CatcherView, coordinator: ()) {
        view.stopListening()
    }

    final class CatcherView: NSView {
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
            guard bounds.contains(point) else { return false }
            onScroll?(ScrollInput(deltaX: event.scrollingDeltaX, deltaY: event.scrollingDeltaY,
                                  isPrecise: event.hasPreciseScrollingDeltas,
                                  zooms: event.modifierFlags.contains(.command),
                                  x: point.x, y: point.y))
            return true
        }
    }
}
