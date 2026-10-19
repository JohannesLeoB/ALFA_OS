import Hub
import Mail
import ShellCore
import SwiftUI

struct MailAccountPicker: View {
    let model: MailModel

    var body: some View {
        if model.accounts.count > 1 {
            ForEach(model.accounts) { account in
                DesignRow(selected: model.selectedInlet == account.id, action: { Task { await model.selectAccount(account.id) } }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(verbatim: account.title).designText()
                            if !account.account.isEmpty {
                                Text(verbatim: account.account).designText(\.inkTertiary, size: Design.TextSize.small)
                            }
                        }
                        Spacer()
                        Text(verbatim: String(model.unread[account.id] ?? 0)).designText(\.inkTertiary)
                    }
                }
            }
            Hairline().padding(.vertical, CGFloat(Design.Spacing.step8))
        }
    }
}
