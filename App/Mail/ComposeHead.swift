import Design
import Hub
import SwiftUI

struct ComposeHead: View {
    @Environment(\.appearance) private var appearance
    let account: Inlet?
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let side = CGFloat(Tokens.Size.symbolSize)
        Button(action: action) {
            HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
                Glyph(.compose)
                    .frame(width: side, height: side)
                    .background(Circle().fill(hovering ? appearance.color(\.hover) : Color.clear))
                    .ring(Circle(), hovering ? appearance.color(\.inkTertiary) : appearance.color(\.ink).opacity(Tokens.Opacity.ringOnMark))
                    .padding(.trailing, CGFloat(Tokens.Spacing.step12))
                appearance.text("mail.action.compose")
                    .typeStyle(Tokens.TextStyle.bodyEmphasis)
                    .lineLimit(1)
                    .layoutPriority(1)
                if let account {
                    Text(verbatim: account.mailboxName)
                        .font(.face(Tokens.TextSize.small))
                        .opacity(Tokens.Opacity.cardMeta)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .foregroundStyle(appearance.color(\.ink))
            .padding(.leading, CGFloat(Tokens.Radius.card - Tokens.Size.symbolSize / 2))
            .padding(.trailing, CGFloat(Tokens.Spacing.step28 + Tokens.Spacing.step20))
            .frame(maxWidth: .infinity, minHeight: CGFloat(Tokens.Spacing.step44), maxHeight: CGFloat(Tokens.Spacing.step44),
                   alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle(scale: Tokens.Scale.pressTile))
        .keyboardShortcut("n", modifiers: .command)
        .help(appearance.text("mail.action.compose"))
        .onHover { hovering = $0 }
        .animation(appearance.ease(Tokens.Duration.hover), value: hovering)
    }
}
