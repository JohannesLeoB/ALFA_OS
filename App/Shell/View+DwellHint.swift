import AppKit
import Design
import SwiftUI

private struct DwellHint: ViewModifier {
    let key: String
    @Environment(\.appearance) private var appearance
    @State private var pointer: CGPoint?
    @State private var anchor: CGPoint?
    @State private var dwelt = 0.0
    @State private var shown: CGPoint?

    func body(content: Content) -> some View {
        content
            .onContinuousHover { phase in
                switch phase {
                case .active(let point): pointer = point
                case .ended: reset(nil)
                }
            }
            .eventMonitor([.leftMouseDown, .rightMouseDown, .keyDown, .scrollWheel], active: pointer != nil) { _ in
                reset(pointer)
                return false
            }
            .task(id: pointer == nil) {
                while pointer != nil, !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(SheetValues.hintTick))
                    step()
                }
            }
            .overlay(alignment: .topLeading) {
                if let shown {
                    appearance.text(key)
                        .font(.face(Tokens.TextSize.small))
                        .foregroundStyle(appearance.color(\.onInverse))
                        .frame(maxWidth: CGFloat(SheetValues.hintMaxWidth), alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, CGFloat(Tokens.Spacing.step4))
                        .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
                        .background(RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.field)).fill(appearance.color(\.inverse)))
                        .fixedSize()
                        .offset(x: shown.x + CGFloat(Tokens.Spacing.step12), y: shown.y + CGFloat(Tokens.Spacing.step16))
                        .allowsHitTesting(false)
                        .transition(.opacity)
                        .zIndex(Double(Tokens.Layer.hint))
                }
            }
            .animation(appearance.ease(Tokens.Duration.hover), value: shown != nil)
    }

    private func step() {
        guard shown == nil, let pointer else { return }
        guard let anchor, hypot(pointer.x - anchor.x, pointer.y - anchor.y) <= CGFloat(Tokens.Size.hintRadius) else {
            self.anchor = pointer
            dwelt = 0
            return
        }
        dwelt += SheetValues.hintTick
        if dwelt >= Tokens.Duration.hintDwell { shown = pointer }
    }

    private func reset(_ point: CGPoint?) {
        pointer = point
        anchor = point
        dwelt = 0
        shown = nil
    }
}

extension View {
    func dwellHint(_ key: String) -> some View {
        modifier(DwellHint(key: key))
    }
}
