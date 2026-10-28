import Design
import Hub
import Mail
import SwiftUI

struct MailboxRow: View {
    @Environment(\.appearance) private var appearance
    let account: Inlet
    let display: MailboxDisplay
    let ink: Color
    var alert = false
    var named = true
    var trailing = Deck.toggleRoom

    var body: some View {
        let side = CGFloat(Tokens.Size.symbolSize)
        DeckRow(trailing: trailing) {
            Text(verbatim: account.mailboxInitials)
                .typeStyle(Tokens.TextStyle.mark)
                .lineLimit(1)
                .frame(width: side, height: side)
                .ring(Circle(), ink.opacity(Tokens.Opacity.ringOnMark))
                .overlay(alignment: .topTrailing) { if alert { AccountAlert() } }
        } label: {
            Text(verbatim: account.shownName(display, appearance: appearance))
                .typeStyle(Tokens.TextStyle.bodyEmphasis)
                .lineLimit(1)
                .truncationMode(.tail)
                .opacity(named ? 1 : 0)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
