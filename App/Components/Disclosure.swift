import Design
import Shell
import SwiftUI

struct Disclosure<Content: View>: View {
    @Environment(\.appearance) private var appearance
    let open: Bool
    let help: String
    @ViewBuilder let content: Content
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
                content
                Glyph.small(.chevron)
                    .foregroundStyle(appearance.color(\.inkTertiary))
                    .rotationEffect(.degrees(open ? SheetValues.halfTurn : 0))
            }
            .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
            .frame(height: CGFloat(Tokens.Spacing.step28))
            .background(Capsule().fill(hovering ? appearance.color(\.hover) : Color.clear))
            .contentShape(Capsule())
        }
        .buttonStyle(PressScaleButtonStyle(scale: SheetValues.pressScaleDisclosure))
        .padding(.leading, -CGFloat(Tokens.Spacing.step8))
        .help(Text(verbatim: help))
        .onHover { hovering = $0 }
        .animation(appearance.ease(Tokens.Duration.chevron), value: open)
    }
}
