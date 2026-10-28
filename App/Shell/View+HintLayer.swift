import Design
import SwiftUI

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
                        .frame(maxWidth: CGFloat(SheetValues.hintMaxWidth), alignment: .leading)
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
