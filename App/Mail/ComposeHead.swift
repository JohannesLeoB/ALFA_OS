import Design
import Hub
import Mail
import SwiftUI

struct ComposeHead: View {
    @Environment(\.appearance) private var appearance
    let account: Inlet?
    let display: MailboxDisplay
    let named: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let side = CGFloat(Tokens.Size.symbolSize)
        let ink = appearance.color(\.ink)
        HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
            Button(action: action) {
                DeckRow(trailing: 0) {
                    Glyph(.compose)
                        .frame(width: side, height: side)
                        .background(Circle().fill(hovering ? appearance.color(\.hover) : Color.clear))
                        .ring(Circle(), hovering ? appearance.color(\.inkTertiary) : ink.opacity(Tokens.Opacity.ringOnMark))
                } label: {
                    appearance.text("mail.action.compose")
                        .typeStyle(Tokens.TextStyle.bodyEmphasis)
                        .lineLimit(1)
                }
                .foregroundStyle(ink)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressScaleButtonStyle(scale: Tokens.Scale.pressTile))
            .keyboardShortcut("n", modifiers: .command)
            .help(appearance.text("mail.action.compose"))
            .onHover { hovering = $0 }
            .layoutPriority(1)
            if let account {
                Text(verbatim: account.mailboxName(display))
                    .typeStyle(Tokens.TextStyle.caption)
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .opacity(named ? Tokens.Opacity.cardMeta : 0)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, Deck.toggleRoom)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Deck.row)
        .animation(appearance.ease(Tokens.Duration.hover), value: hovering)
    }
}
