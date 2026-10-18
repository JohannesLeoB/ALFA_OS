import ShellCore
import SwiftUI

struct LaneView: View {
    let theme: Theme
    let model: ShellModel
    let lane: Lane
    let titleKey: String
    let size: CGSize

    private var folded: Bool { lane != .center && Double(size.width) <= theme.geometry.laneFolded }
    private var maximized: Bool { model.laneState(model.currentID).maximized == lane }

    var body: some View {
        let radius = theme.length(.componentLaneRadius)
        VStack(spacing: 0) {
            header
            Rectangle()
                .fill(theme.design(\.line))
                .frame(height: theme.length(.strokeHairline))
                .opacity(folded ? 0 : 1)
            content
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .background(theme.design(\.lane))
        .clipShape(RoundedRectangle(cornerRadius: radius))
        .overlay(
            RoundedRectangle(cornerRadius: radius)
                .strokeBorder(theme.design(\.line), lineWidth: theme.length(.strokeHairline))
        )
        .environment(\.design, DesignStyle(dark: theme.mode == .dark))
        .environment(\.laneFill, theme.design(\.lane))
        .environment(\.hairline, theme.length(.strokeHairline))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(theme.text(titleKey))
    }

    private var header: some View {
        HStack(spacing: theme.length(.spaceS)) {
            if !folded, !titleKey.isEmpty {
                theme.text(titleKey)
                    .font(theme.font(.name))
                    .tracking(theme.tracking(.name))
                    .foregroundStyle(theme.design(\.ink))
                    .lineLimit(1)
            }
            if !folded {
                Spacer(minLength: 0)
            }
            if lane != .center {
                button(symbol: folded ? "plus" : "minus", label: folded ? "lane.unfold" : "lane.fold") {
                    model.toggleFold(lane)
                }
            }
            if !folded {
                button(symbol: maximized ? "arrow.down.left" : "arrow.up.right", label: maximized ? "lane.restore" : "lane.maximize") {
                    model.toggleMaximize(lane)
                }
            }
        }
        .padding(.leading, folded ? 0 : theme.length(.spaceL))
        .padding(.trailing, folded ? 0 : CGFloat(Design.Size.headPadRight))
        .frame(maxWidth: .infinity)
        .frame(height: theme.length(.componentLaneHeaderHeight))
    }

    private func button(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(theme.font(.textButton))
                .foregroundStyle(theme.design(\.inkTertiary))
                .frame(width: CGFloat(Design.Size.symbolSize), height: CGFloat(Design.Size.symbolSize))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.text(label))
    }

    @ViewBuilder
    private var content: some View {
        if folded {
            Color.clear.frame(maxHeight: .infinity)
        } else if model.currentID == "mail" {
            MailLaneView(lane: lane)
        } else if model.currentID == "settings" {
            SettingsLaneView(lane: lane)
        } else {
            Color.clear.frame(maxHeight: .infinity)
        }
    }
}
