import AppKit
import Design
import Shell
import SwiftUI

struct EventSample {
    let event: NSEvent
    let local: CGPoint?
}

private struct EventMonitor: ViewModifier {
    @Environment(\.appLocked) private var locked
    let mask: NSEvent.EventTypeMask
    let active: Bool
    let onEvent: (EventSample) -> Bool

    func body(content: Content) -> some View {
        content.background(MonitorAnchor(mask: mask, active: active && !locked, onEvent: onEvent))
    }
}

private struct MonitorAnchor: NSViewRepresentable {
    let mask: NSEvent.EventTypeMask
    let active: Bool
    let onEvent: (EventSample) -> Bool

    func makeNSView(context: Context) -> MonitorView {
        MonitorView()
    }

    func updateNSView(_ view: MonitorView, context: Context) {
        view.onEvent = onEvent
        view.listen(active, mask: mask)
    }

    static func dismantleNSView(_ view: MonitorView, coordinator: ()) {
        view.listen(false, mask: [])
    }
}

private final class MonitorView: NSView {
    var onEvent: (EventSample) -> Bool = { _ in false }
    private var monitor: Any?

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func listen(_ on: Bool, mask: NSEvent.EventTypeMask) {
        if on, monitor == nil {
            monitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
                let consumed = MainActor.assumeIsolated { self?.deliver(event) ?? false }
                return consumed ? nil : event
            }
        } else if !on, let current = monitor {
            NSEvent.removeMonitor(current)
            monitor = nil
        }
    }

    private func deliver(_ event: NSEvent) -> Bool {
        let local = event.window === window ? convert(event.locationInWindow, from: nil) : nil
        return onEvent(EventSample(event: event, local: local))
    }
}

extension View {
    func eventMonitor(_ mask: NSEvent.EventTypeMask, active: Bool = true, _ onEvent: @escaping (EventSample) -> Bool) -> some View {
        modifier(EventMonitor(mask: mask, active: active, onEvent: onEvent))
    }
}

extension View {
    func clickAway(active: Bool, inside: CGRect, perform away: @escaping () -> Void) -> some View {
        eventMonitor(.leftMouseDown, active: active) { sample in
            if let local = sample.local, !inside.contains(local) { away() }
            return false
        }
    }
}
