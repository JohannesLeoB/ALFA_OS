import Design
import Hub
import Mail
import SwiftUI

struct AccountTitle: View {
    @Environment(\.appearance) private var appearance
    let account: Inlet
    let display: MailboxDisplay
    let choose: (MailboxDisplay) -> Void
    @State private var anchor = AnchorBox()

    var body: some View {
        Text(verbatim: account.shownName(display, appearance: appearance))
            .designText(\.ink, size: Tokens.TextSize.body, weight: .medium)
            .lineLimit(1)
            .truncationMode(.tail)
            .help(Text(verbatim: account.account))
            .overlay {
                RightClickOverlay { point in
                    MailboxMenu.show(for: account, current: display, at: point, appearance: appearance, choose: choose)
                }
            }
            .background(AnchorMarker(box: anchor))
            .accessibilityAction(named: appearance.text("mail.account.show")) {
                anchor.showMenu(MailboxMenu.entries(for: account, current: display, appearance: appearance, choose: choose))
            }
    }
}
