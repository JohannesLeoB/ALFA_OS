import ShellCore
import SwiftUI

struct ShellView: View {
    let resources: ShellResources
    let bundle: Bundle
    @Bindable var model: ShellModel
    @Environment(\.colorScheme) private var scheme
    @State private var dragCenter: CGPoint?

    private var theme: Theme {
        Theme(tokens: resources.tokens, geometry: resources.geometry, metrics: resources.metrics, mode: scheme == .dark ? .dark : .light, bundle: bundle)
    }

    var body: some View {
        let theme = theme
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                theme.color(.colorBackgroundWindow)
                lanes(theme)
                handles(theme)
                PersonPillView(theme: theme)
                    .offset(x: pillX(proxy.size.width, theme), y: blobTop(theme))
                if model.menuOpen || model.assistantOpen {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            model.closeMenu()
                            model.closeAssistant()
                        }
                }
                menu(theme)
                BlobView(theme: theme, model: model, dragCenter: $dragCenter)
                if model.assistantOpen {
                    AssistantView(theme: theme, model: model)
                        .offset(x: assistantOrigin(theme).x, y: assistantOrigin(theme).y)
                }
            }
            .coordinateSpace(name: "shell")
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .onAppear { model.resize(Size(width: proxy.size.width, height: proxy.size.height)) }
            .onChange(of: proxy.size) { _, size in model.resize(Size(width: size.width, height: size.height)) }
        }
        .onExitCommand {
            model.closeMenu()
            model.closeAssistant()
        }
        .ignoresSafeArea(edges: [.horizontal, .bottom])
    }

    private func blobTop(_ theme: Theme) -> CGFloat {
        (theme.length(.componentBlobBarHeight) - theme.length(.componentBlobHeight)) / 2
    }

    private func pillX(_ width: CGFloat, _ theme: Theme) -> CGFloat {
        let pill = theme.length(.spaceXs) * 3 + theme.length(.sizeControlM) * 2
        return width - theme.length(.componentLaneEdge) - theme.length(.spaceS) - pill
    }

    private func assistantOrigin(_ theme: Theme) -> CGPoint {
        let menu = model.blob.menuOrigin(window: model.window, geometry: theme.geometry)
        let width = CGFloat(theme.geometry.assistantWidth)
        let margin = theme.length(.componentLaneEdge)
        let x = min(CGFloat(model.window.width) - margin - width, max(margin, CGFloat(menu.origin.x)))
        let y = menu.opensDownward ? CGFloat(menu.origin.y) : max(margin, CGFloat(menu.origin.y) - theme.length(.layoutReadingMaxWidth) / 2)
        return CGPoint(x: x, y: y)
    }

    private func lanes(_ theme: Theme) -> some View {
        let widths = model.widths
        let g = theme.geometry
        let height = CGFloat(model.window.height - g.strip - g.margin)
        let entry = model.current
        let positions: [(Lane, String, Double)] = [
            (.leading, entry?.lanes.leadingKey ?? "", g.margin),
            (.center, entry?.lanes.centerKey ?? "", g.margin + widths.leading + g.gap),
            (.trailing, entry?.lanes.trailingKey ?? "", g.margin + widths.leading + g.gap + widths.center + g.gap)
        ]
        return ZStack(alignment: .topLeading) {
            ForEach(positions, id: \.0) { item in
                LaneView(theme: theme, model: model, lane: item.0, titleKey: item.1, size: CGSize(width: widths.width(item.0), height: height))
                    .offset(x: CGFloat(item.2), y: CGFloat(g.strip))
            }
        }
        .animation(isDragging ? nil : theme.animation(.motionDurationChange), value: widths)
    }

    private var isDragging: Bool { dragCenter != nil }

    private func handles(_ theme: Theme) -> some View {
        let widths = model.widths
        let g = theme.geometry
        let height = CGFloat(model.window.height - g.strip - g.margin)
        let leftX = g.margin + widths.leading
        let rightX = leftX + g.gap + widths.center
        return ZStack(alignment: .topLeading) {
            HandleView(theme: theme, model: model, lane: .leading, height: height).offset(x: CGFloat(leftX), y: CGFloat(g.strip))
            HandleView(theme: theme, model: model, lane: .trailing, height: height).offset(x: CGFloat(rightX), y: CGFloat(g.strip))
        }
        .animation(theme.animation(.motionDurationChange), value: widths)
    }

    @ViewBuilder
    private func menu(_ theme: Theme) -> some View {
        let g = theme.geometry
        let placement = model.blob.menuOrigin(window: model.window, geometry: g)
        let downward = placement.opensDownward
        let space = downward
            ? CGFloat(model.window.height - placement.origin.y - g.margin)
            : CGFloat(placement.origin.y - g.margin)
        let view = BlobMenuView(theme: theme, model: model, available: max(space, 0))
        if downward {
            view.offset(x: CGFloat(placement.origin.x), y: CGFloat(placement.origin.y))
        } else {
            view.frame(height: CGFloat(placement.origin.y), alignment: .bottom)
                .offset(x: CGFloat(placement.origin.x), y: 0)
        }
    }
}
