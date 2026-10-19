import ShellCore
import SwiftUI

struct LaneView: View {
    let theme: Theme
    let model: ShellModel
    let lane: Lane
    let titleKey: String
    let size: CGSize

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
            VStack(spacing: 0) {
                header
                content
            }
            .frame(width: inner, height: size.height, alignment: .topLeading)
            .opacity(strip ? 0 : 1)
            .allowsHitTesting(!strip)
            .animation(fade, value: strip)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .background(theme.design(\.lane))
        .clipShape(shape)
        .themeShadow(theme, layers: theme.designShadow(\.lane), shape: shape)
        .environment(\.design, DesignStyle(dark: theme.dark))
        .environment(\.laneFill, theme.design(\.lane))
        .environment(\.hairline, CGFloat(Design.Size.hairline))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(theme.text(titleKey))
    }

    private var header: some View {
        HStack(spacing: CGFloat(Design.Size.headGapList)) {
            if !titleKey.isEmpty {
                theme.text(titleKey)
                    .font(theme.font(weight: Design.Weight.medium))
                    .foregroundStyle(theme.design(\.ink))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, CGFloat(Design.Size.headPadLeftList))
        .padding(.trailing, CGFloat(Design.Size.headPadRight))
        .frame(height: CGFloat(Design.Size.headerHeight))
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
