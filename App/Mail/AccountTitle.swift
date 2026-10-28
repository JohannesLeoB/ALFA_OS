import Design
import Hub
import SwiftUI

struct AccountTitle: View {
    @Environment(\.appearance) private var appearance
    let account: Inlet
    let display: MailboxDisplay
    let choose: (MailboxDisplay) -> Void

    var body: some View {
        Text(verbatim: account.mailboxName(display))
            .designText(\.ink, size: Tokens.TextSize.body, weight: .medium)
            .lineLimit(1)
            .truncationMode(.tail)
            .help(Text(verbatim: account.account))
            .overlay {
                RightClickOverlay { point in
                    MailboxDisplay.showMenu(for: account, current: display, at: point, appearance: appearance, choose: choose)
                }
            }
    }
}
