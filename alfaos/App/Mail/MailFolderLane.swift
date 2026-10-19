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

private struct ComposeButton: View {
    @Environment(\.design) private var design
    @Environment(\.hairline) private var hairline
    @Environment(\.accessibilityReduceMotion) private var reduced
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: CGFloat(SheetValues.rowSpacing)) {
                Glyph(.compose)
                    .frame(width: CGFloat(Design.Size.symbolSize), height: CGFloat(Design.Size.symbolSize))
                    .overlay(Circle().strokeBorder(design.color(\.onInverse).opacity(Design.Opacity.ringOnColor), lineWidth: hairline))
                word("mail.action.compose")
                    .designText(\.onInverse, size: Design.TextSize.body)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, CGFloat(Design.Spacing.step8))
            .padding(.trailing, CGFloat(Design.Spacing.step12))
            .frame(height: CGFloat(Design.Size.rowHeight))
            .background(RoundedRectangle(cornerRadius: CGFloat(Design.Radius.row)).fill(design.color(\.inverse)))
            .opacity(hovering ? SheetValues.hoverRowOpacity : 1)
            .contentShape(RoundedRectangle(cornerRadius: CGFloat(Design.Radius.row)))
        }
        .buttonStyle(PressScale(scale: SheetValues.pressScaleCompose))
        .keyboardShortcut("n", modifiers: .command)
        .help(word("mail.action.compose"))
        .padding(CGFloat(Design.Spacing.step8))
        .onHover { hovering = $0 }
        .animation(ComponentMotion(reduced: reduced).curve(Design.Duration.hover), value: hovering)
    }
}
