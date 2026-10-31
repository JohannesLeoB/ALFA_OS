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
    let handler: (EventSample) -> Bool

    func body(content: Content) -> some View {
        content.background(MonitorAnchor(mask: mask, active: active && !locked, handler: handler))
    }
}

private struct MonitorAnchor: NSViewRepresentable {
    let mask: NSEvent.EventTypeMask
    let active: Bool
    let handler: (EventSample) -> Bool

    func makeNSView(context: Context) -> MonitorView {
        MonitorView()
    }

    func updateNSView(_ view: MonitorView, context: Context) {
        view.handler = handler
        view.listen(active, mask: mask)
    }

    static func dismantleNSView(_ view: MonitorView, coordinator: ()) {
        view.listen(false, mask: [])
    }
}

private final class MonitorView: NSView {
    var handler: (EventSample) -> Bool = { _ in false }
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
        return handler(EventSample(event: event, local: local))
    }
}

extension View {
    func eventMonitor(_ mask: NSEvent.EventTypeMask, active: Bool = true, _ handler: @escaping (EventSample) -> Bool) -> some View {
        modifier(EventMonitor(mask: mask, active: active, handler: handler))
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

private struct HintLayer: ViewModifier {
    @Environment(\.appearance) private var appearance

    func body(content: Content) -> some View {
        content.overlayPreferenceValue(HintPreference.self, alignment: .topLeading) { hint in
            ZStack(alignment: .topLeading) {
                if let hint {
                    appearance.text(hint.key)
                        .font(.face(Tokens.TextSize.small))
                        .lineHeight(Tokens.LineHeight.body * Tokens.TextSize.small, size: Tokens.TextSize.small)
                        .foregroundStyle(appearance.color(\.onInverse))
                        .frame(maxWidth: CGFloat(Tokens.Size.hintMaxWidth), alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, CGFloat(Tokens.Spacing.step4))
                        .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
                        .background(RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.field)).fill(appearance.color(\.inverse)))
                        .fixedSize()
                        .offset(x: hint.point.x, y: hint.point.y)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .allowsHitTesting(false)
            .animation(appearance.ease(Tokens.Duration.hover), value: hint != nil)
        }
    }
}

extension View {
    func dwellHintLayer() -> some View {
        modifier(HintLayer())
    }
}

private struct DwellHint: ViewModifier {
    let key: String
    let focused: Bool
    @Environment(\.appearance) private var appearance
    @State private var pointer: CGPoint?
    @State private var anchor: CGPoint?
    @State private var dwelt = 0.0
    @State private var shown: CGPoint?
    @State private var place = CGRect.zero

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Frame.space)) } action: { place = $0 }
            .onChange(of: focused) { _, now in
                shown = now ? CGPoint(x: place.width + CGFloat(Tokens.Spacing.step8), y: 0) : nil
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let point): pointer = point
                case .ended: reset(nil)
                }
            }
            .eventMonitor([.leftMouseDown, .leftMouseDragged, .rightMouseDown, .keyDown, .scrollWheel], active: pointer != nil || shown != nil) { _ in
                reset(pointer)
                return false
            }
            .task(id: pointer == nil) {
                while pointer != nil, !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(SheetValues.hintTick))
                    step()
                }
            }
            .preference(key: HintPreference.self, value: shown.map { HintPreference.Hint(key: key, point: CGPoint(x: place.minX + $0.x, y: place.minY + $0.y)) })
    }

    private func step() {
        guard shown == nil, let pointer else { return }
        guard let anchor, hypot(pointer.x - anchor.x, pointer.y - anchor.y) <= CGFloat(Tokens.Size.hintRadius) else {
            self.anchor = pointer
            dwelt = 0
            return
        }
        dwelt += SheetValues.hintTick
        if dwelt >= Tokens.Duration.hintDwell { shown = CGPoint(x: pointer.x + CGFloat(Tokens.Spacing.step12), y: pointer.y + CGFloat(Tokens.Spacing.step16)) }
    }

    private func reset(_ point: CGPoint?) {
        pointer = point
        anchor = point
        dwelt = 0
        shown = nil
    }
}

extension View {
    func dwellHint(_ key: String, focused: Bool = false) -> some View {
        modifier(DwellHint(key: key, focused: focused))
    }
}

private struct SearchFade: ViewModifier, Animatable {
    var progress: Double

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let start = SheetValues.tapeFadeAt
        content.opacity(progress < start ? 0 : (progress - start) / (1 - start))
    }
}

extension View {
    func searchFade(progress: Double) -> some View {
        modifier(SearchFade(progress: progress))
    }
}
