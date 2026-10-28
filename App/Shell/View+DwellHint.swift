import AppKit
import Design
import SwiftUI

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
