import Core
import Design
import Mail
import Shell
import SwiftUI

struct FolderLane: View {
    let session: AppSession
    @Environment(\.appearance) private var appearance
    @State private var scrolled = false

    private var inbox: InboxState { session.inbox }

    private var desk: DeskState { session.desk }

    private var detail: (text: String, failing: Bool) {
        switch inbox.listState {
        case .notConnected: (appearance.string("mail.lane.detail.none"), false)
        case .signInExpired: (appearance.string("mail.lane.detail.unreachable"), true)
        default: (PersonName.middle(inbox.address, limit: SheetValues.headerAddressLimit), false)
        }
    }

    private var openLanes: Int {
        desk.widths.all.filter { $0 > desk.measure.laneFolded }.count
    }

    var body: some View {
        let state = detail
        VStack(spacing: 0) {
            LaneHead(scrolled: scrolled, lane: .leading) {
                HeaderTitle(text: appearance.text("mail.lane.title"))
                SmallText(text: Text(verbatim: state.text), tone: state.failing ? \.signal : \.inkTertiary)
                    .help(Text(verbatim: state.text))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if openLanes > 1 {
                    SymbolButton(help: appearance.string("mail.lane.fold"), glyph: .minus) { desk.toggleFold(.leading) }
                }
            }
            ScrollView {
                VStack(spacing: 0) {
                    AccountList(inbox: inbox)
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
            ComposeButton { inbox.compose() }
        }
    }

    @ViewBuilder
    private var labels: some View {
        let rows = inbox.labelRows
        if !rows.isEmpty {
            appearance.text("mail.lane.labels")
                .designText(\.inkTertiary, size: Tokens.TextSize.small)
                .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
                .padding(.bottom, CGFloat(Tokens.Spacing.step8))
                .frame(maxWidth: .infinity, minHeight: CGFloat(Tokens.Spacing.step32), alignment: .bottomLeading)
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

struct ComposeButton: View {
    @Environment(\.appearance) private var appearance
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.row))
        Button(action: action) {
            HStack(spacing: CGFloat(SheetValues.rowSpacing)) {
                Glyph(.compose)
                    .foregroundStyle(appearance.color(\.onInverse))
                    .frame(width: CGFloat(Tokens.Size.symbolSize), height: CGFloat(Tokens.Size.symbolSize))
                    .overlay(Circle().strokeBorder(appearance.color(\.onInverse).opacity(Tokens.Opacity.ringOnColor), lineWidth: CGFloat(Tokens.Size.hairline)))
                appearance.text("mail.action.compose")
                    .designText(\.onInverse, size: Tokens.TextSize.body)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, CGFloat(Tokens.Spacing.step8))
            .padding(.trailing, CGFloat(Tokens.Spacing.step12))
            .frame(height: CGFloat(Tokens.Size.rowHeight))
            .background(shape.fill(appearance.color(\.inverse)))
            .opacity(hovering ? SheetValues.hoverRowOpacity : 1)
            .contentShape(shape)
        }
        .buttonStyle(PressScaleButtonStyle(scale: SheetValues.pressScaleCompose))
        .keyboardShortcut("n", modifiers: .command)
        .help(appearance.text("mail.action.compose"))
        .padding(CGFloat(Tokens.Spacing.step8))
        .onHover { hovering = $0 }
        .animation(appearance.ease(Tokens.Duration.hover), value: hovering)
    }
}
