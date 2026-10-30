import Core
import Design
import Hub
import Mail
import Shell
import SwiftUI

struct FolderLane: View {
    let session: AppSession
    @Environment(\.appearance) private var appearance
    @State private var scrolled = false

    private var inbox: InboxState { session.inbox }

    private var desk: DeskState { session.desk }

    private var current: Inlet? { inbox.selectedAccount }

    private var openLanes: Int {
        desk.widths.all.filter { $0 > desk.measure.laneFolded }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                head
                list
            }
            .switchGlass(session.mailboxSwitching)
            AccountDeck(session: session)
        }
    }

    private var head: some View {
        LaneHead(scrolled: scrolled, lane: .leading) {
            if let current {
                AccountTitle(account: current, display: session.settings.display(current.id)) {
                    session.settings.setDisplay($0, for: current.id)
                }
            } else {
                HeaderTitle(text: appearance.text("mail.lane.title"))
            }
            Spacer(minLength: 0)
            if openLanes > 1 {
                SymbolButton(help: appearance.string("mail.lane.fold"), glyph: .minus) { desk.toggleFold(.leading) }
            }
        }
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(inbox.folderRows) { row in
                    let live = inbox.accountReachable && inbox.listState != .loading
                    LaneRow(glyph: row.glyph, label: name(row), selected: row.selected,
                            count: live && row.count > 0 ? Format.number(row.count) : nil,
                            countTone: row.selected ? \.onInverseSecondary : \.inkTertiary) {
                        Task { await inbox.selectFolder(row.folder.id) }
                    }
                }
                labels
            }
            .padding(CGFloat(Tokens.Spacing.step8))
        }
        .scrollIndicators(.hidden)
        .scrolledSignal($scrolled)
    }

    @ViewBuilder
    private var labels: some View {
        let rows = inbox.labelRows
        if !rows.isEmpty {
            if inbox.showsLabelHeading {
                appearance.text("mail.lane.labels")
                    .designText(\.inkTertiary, size: Tokens.TextSize.small)
                    .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
                    .padding(.bottom, CGFloat(Tokens.Spacing.step8))
                    .frame(maxWidth: .infinity, minHeight: CGFloat(Tokens.Spacing.step32), alignment: .bottomLeading)
            }
            ForEach(rows) { row in
                LaneRow(glyph: row.glyph, label: Text(verbatim: row.folder.name), selected: row.selected, count: nil) {
                    Task { await inbox.selectFolder(row.folder.id) }
                }
            }
        }
    }

    private func name(_ row: FolderEntry) -> Text {
        row.folder.role == .other ? Text(verbatim: row.folder.name) : appearance.text("mail.role." + row.folder.role.rawValue)
    }
}
