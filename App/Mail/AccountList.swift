import Design
import Hub
import Mail
import SwiftUI

struct AccountList: View {
    let inbox: InboxState

    var body: some View {
        if inbox.accounts.count > 1 {
            ForEach(inbox.accounts) { account in
                DesignRow(selected: inbox.selectedInlet == account.id, action: { Task { await inbox.selectAccount(account.id) } }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(verbatim: account.title).designText()
                            if !account.account.isEmpty {
                                Text(verbatim: account.account).designText(\.inkTertiary, size: Tokens.TextSize.small)
                            }
                        }
                        Spacer()
                        Text(verbatim: String(inbox.unread[account.id] ?? 0)).designText(\.inkTertiary)
                    }
                }
            }
            Hairline().padding(.vertical, CGFloat(Tokens.Spacing.step8))
        }
    }
}

struct DesignRow<Content: View>: View {
    @Environment(\.appearance) private var appearance
    let selected: Bool
    let action: () -> Void
    @ViewBuilder let content: Content
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            content
                .padding(.horizontal, CGFloat(Tokens.Spacing.step12))
                .padding(.vertical, CGFloat(Tokens.Spacing.step4))
                .frame(maxWidth: .infinity, minHeight: CGFloat(Tokens.Size.rowHeight), alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.row))
                        .fill(selected ? appearance.color(\.selection) : (hovering ? appearance.color(\.hover) : Color.clear))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
