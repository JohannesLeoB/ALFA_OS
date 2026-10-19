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
        default: (MailNames.middle(model.address, limit: MailSheet.headerAddressLimit), false)
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
                    HeadSymbol(help: words("mail.lane.fold"), glyph: .minus) { link.fold(.leading) }
                }
            }
            ScrollView {
                VStack(spacing: 0) {
                    MailAccountPicker(model: model)
                    ForEach(model.folderRows) { row in
                        FolderRowView(row: row, live: model.accountReachable && model.listState != .loading) {
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
}

private struct FolderRowView: View {
    @Environment(\.design) private var design
    let row: MailFolderRow
    let live: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let name = row.folder.role == .other ? Text(verbatim: row.folder.name) : word("mail.role." + row.folder.role.rawValue)
        Button(action: action) {
            HStack(spacing: CGFloat(MailSheet.rowSpacing)) {
                Mark(fill: .rest, inverted: row.selected, tone: row.selected ? \.lane : \.inkTertiary) { Glyph(row.glyph) }
                name
                    .designText(row.selected ? \.lane : \.ink, size: Design.TextSize.body, weight: row.selected ? .medium : .regular)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if live, row.count > 0 {
                    Counter(value: MailNames.number(row.count), tone: row.selected ? \.onInverseSecondary : \.inkTertiary)
                }
            }
            .padding(.horizontal, CGFloat(Design.Spacing.step8))
            .frame(height: CGFloat(Design.Size.rowHeight))
            .background(RoundedRectangle(cornerRadius: CGFloat(Design.Radius.row)).fill(row.selected ? design.color(\.ink) : Color.clear))
            .ring(RoundedRectangle(cornerRadius: CGFloat(Design.Radius.row)), hovering && !row.selected ? design.color(\.lineStrong) : nil)
            .contentShape(RoundedRectangle(cornerRadius: CGFloat(Design.Radius.row)))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityAddTraits(row.selected ? .isSelected : [])
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
            HStack(spacing: CGFloat(MailSheet.rowSpacing)) {
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
            .opacity(hovering ? MailSheet.hoverRowOpacity : 1)
            .contentShape(RoundedRectangle(cornerRadius: CGFloat(Design.Radius.row)))
        }
        .buttonStyle(PressScale(scale: MailSheet.pressScaleCompose))
        .keyboardShortcut("n", modifiers: .command)
        .help(word("mail.action.compose"))
        .padding(CGFloat(Design.Spacing.step8))
        .onHover { hovering = $0 }
        .animation(ComponentMotion(reduced: reduced).curve(Design.Duration.hover), value: hovering)
    }
}

struct PressScale: ButtonStyle {
    let scale: Double

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? CGFloat(scale) : 1)
    }
}
