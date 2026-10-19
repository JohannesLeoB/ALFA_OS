import Mail
import ShellCore
import SwiftUI

struct MailFolderLane: View {
    let model: MailModel
    @Environment(\.mailLaneLink) private var link
    @State private var scrolled = false

    private var detail: (text: String, failing: Bool) {
        switch model.listState {
        case .notConnected: (words("mail.lane.detail.none"), false)
        case .signInExpired: (words("mail.lane.detail.unreachable"), true)
        default: (MailNames.middle(model.address, limit: SheetValues.headerAddressLimit), false)
        }
    }

    var body: some View {
        let state = detail
        VStack(spacing: 0) {
            LaneHead(scrolled: scrolled) {
                HeaderTitle(text: word("mail.lane.title"))
                SmallText(text: Text(verbatim: state.text), tone: state.failing ? \.signal : \.inkTertiary)
                    .help(Text(verbatim: state.text))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let link, link.openLanes > 1 {
                    SymbolButton(help: words("mail.lane.fold"), glyph: .minus) { link.fold(.leading) }
                }
            }
            ScrollView {
                VStack(spacing: 0) {
                    MailAccountPicker(model: model)
                    ForEach(model.folderRows) { row in
                        let live = model.accountReachable && model.listState != .loading
                        LaneRow(glyph: row.glyph, label: name(row), selected: row.selected,
                                count: live && row.count > 0 ? MailNames.number(row.count) : nil,
                                countTone: row.selected ? \.onInverseSecondary : \.inkTertiary) {
                            Task { await model.selectFolder(row.folder.id) }
                        }
                    }
                }
                .padding(CGFloat(Design.Spacing.step8))
            }
            .scrollIndicators(.hidden)
            .scrolledSignal($scrolled)
            ComposeButton { _ = model.compose() }
        }
    }

    private func name(_ row: MailFolderRow) -> Text {
        row.folder.role == .other ? Text(verbatim: row.folder.name) : word("mail.role." + row.folder.role.rawValue)
    }
}
