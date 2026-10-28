import Design
import Hub
import SwiftUI

struct AccountTitle: View {
    let account: Inlet

    var body: some View {
        Text(verbatim: account.mailboxName)
            .designText(\.ink, size: Tokens.TextSize.body, weight: .medium)
            .lineLimit(1)
            .truncationMode(.tail)
            .help(Text(verbatim: account.account))
    }
}
