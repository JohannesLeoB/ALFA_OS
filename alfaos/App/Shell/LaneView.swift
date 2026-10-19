import Mail
import ShellCore
import SwiftUI

struct LaneView: View {
    let theme: Theme
    let model: ShellModel
    let lane: Lane
    let titleKey: String
    let size: CGSize
    @Environment(\.appHost) private var host
    @Environment(\.hostLive) private var live

    private var ownHead: Bool {
        model.currentID == "mail" || (model.currentID == "settings" && lane == .trailing && live && host?.mail != nil)
    }

    private var titleString: String {
        lane == .center && model.currentID == "settings" ? theme.string(SettingsShared.board.group.key) : theme.string(titleKey)
    }

    private var title: Text {
        guard lane == .center else { return theme.text(titleKey) }
        switch model.currentID {
        case "mail": return host?.mail.map { Text(verbatim: folderTitle($0.currentFolderName)) } ?? theme.text(titleKey)
        case "settings": return theme.text(SettingsShared.board.group.key)
        default: return theme.text(titleKey)
        }
    }

    var body: some View {
        let g = theme.geometry
        let shape = RoundedRectangle(cornerRadius: CGFloat(Design.Radius.lane))
        let folded = Double(size.width) <= g.laneFolded
        let strip = Double(size.width) < g.foldAt
        let inner = max(size.width, CGFloat(g.minimum[lane.index]))
        let fade = theme.ease(Design.Duration.hover)
        ZStack(alignment: .topLeading) {
            if folded {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { model.openStrip(lane) }
                    .pointerStyle(.link)
            }
            marks
                .frame(width: size.width, height: size.height, alignment: .top)
                .opacity(strip ? 1 : 0)
                .allowsHitTesting(strip)
                .accessibilityHidden(!strip)
                .animation(fade, value: strip)
            VStack(spacing: 0) {
                if !ownHead { header }
                content
            }
            .frame(width: inner, height: size.height, alignment: .topLeading)
            .opacity(strip ? 0 : 1)
            .allowsHitTesting(!strip)
            .accessibilityHidden(strip)
            .animation(fade, value: strip)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .background(theme.design(\.lane))
        .clipShape(shape)
        .themeShadow(theme, layers: theme.designShadow(\.lane), shape: shape)
        .environment(\.design, DesignStyle(dark: theme.dark))
        .environment(\.laneFill, theme.design(\.lane))
        .environment(\.hairline, CGFloat(Design.Size.hairline))
        .environment(\.mailLaneLink, MailLaneLink(shell: model))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private var marks: some View {
        if live, model.currentID == "mail", let mail = host?.mail {
            MailStripMarks(model: mail, lane: lane, height: Double(size.height))
        } else if live, model.currentID == "settings", let host {
            SettingsStripMarks(host: host, lane: lane, height: Double(size.height))
        }
    }

    private var header: some View {
        HStack(spacing: CGFloat(lane.headGap)) {
            title
                .font(theme.font(weight: Design.Weight.medium))
                .foregroundStyle(theme.design(\.ink))
                .lineLimit(1)
            Spacer(minLength: 0)
            if model.currentID == "settings" { tools }
        }
        .padding(.leading, CGFloat(lane.headLeading))
        .padding(.trailing, CGFloat(lane.headTrailing))
        .frame(height: CGFloat(Design.Size.headerHeight))
    }

    @ViewBuilder
    private var tools: some View {
        let open = model.widths.all.filter { $0 > model.geometry.laneFolded }.count
        let name = titleString
        if open > 1 {
            SymbolButton(help: String(format: theme.string("mail.fold.named"), name), glyph: .minus) { model.toggleFold(lane) }
        }
        if lane == .center {
            let maxed = model.laneState(model.currentID).maximized == .center
            SymbolButton(help: maxed ? theme.string("mail.lane.back") : String(format: theme.string("mail.grow.named"), name),
                         glyph: maxed ? .shrink : .expand) { model.toggleMaximize(.center) }
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.currentID == "mail" {
            MailLaneView(lane: lane)
        } else if model.currentID == "settings" {
            SettingsLaneView(lane: lane)
        } else {
            Color.clear.frame(maxHeight: .infinity)
        }
    }
}
