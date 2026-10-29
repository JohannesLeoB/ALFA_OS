import Design
import Hub
import SwiftUI

struct AccountCard: View {
    @Environment(\.appearance) private var appearance
    let account: Inlet
    let display: MailboxDisplay
    let level: Int
    let last: Bool
    let alert: Bool
    let named: Bool
    let choose: (MailboxDisplay) -> Void
    let action: () -> Void
    @State private var hovering = false
    @State private var anchor = AnchorBox()

    private var step: StackStep { appearance.stackStep(level) }

    var body: some View {
        let ink = appearance.paint(step.ink)
        let shape = Deck.bottomRounded(Tokens.Radius.card)
        Button(action: action) {
            MailboxRow(account: account, display: display, ink: ink, alert: alert, named: named)
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .background(appearance.paint(step.surface).animation(appearance.ease(Tokens.Duration.stackBackground, Tokens.Easing.stack), value: level))
                .lacquer(shape, step: step, seam: \.stackSeamBack, drop: !last)
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .overlay {
            RightClickOverlay { point in
                MailboxMenu.show(for: account, current: display, at: point, appearance: appearance, choose: choose)
            }
        }
        .background(AnchorMarker(box: anchor))
        .offset(y: !last && hovering ? CGFloat(SheetValues.stackHoverLift) : 0)
        .onHover { hovering = $0 }
        .help(Text(verbatim: account.account))
        .accessibilityLabel(Text(verbatim: account.account))
        .accessibilityValue(alert ? appearance.text("mail.row.unread") : Text(verbatim: ""))
        .accessibilityAction(named: appearance.text("mail.account.show")) {
            anchor.showMenu(MailboxMenu.entries(for: account, current: display, appearance: appearance, choose: choose))
        }
        .animation(appearance.ease(SheetValues.deckLift, Tokens.Easing.envelopeSpring), value: hovering)
    }
}
