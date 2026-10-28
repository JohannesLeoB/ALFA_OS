import Design
import Shell
import SwiftUI

struct OverviewTile: View {
    @Environment(\.appearance) private var appearance
    let entry: OverviewEntry
    let index: Int
    let size: OverviewSize
    let hot: Bool
    let dimmed: Bool
    let aim: (String?) -> Void
    @State private var entered = false

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.row)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            head
            VStack(alignment: .leading, spacing: CGFloat(Tokens.Spacing.step4)) {
                Text(verbatim: entry.subject)
                    .designText(\.ink, size: Tokens.TextSize.body, weight: .medium)
                    .lineLimit(SheetValues.overviewTitleLines)
                    .lineHeight(Tokens.LineHeight.body * Tokens.TextSize.body, size: Tokens.TextSize.body)
                Text(verbatim: entry.preview)
                    .designText(\.inkSecondary, size: Tokens.TextSize.body)
                    .lineLimit(size.lines)
                    .lineHeight(SheetValues.overviewTileTextLine * Tokens.TextSize.body, size: Tokens.TextSize.body)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, CGFloat(Tokens.Size.edge))
            .padding(.top, CGFloat(Tokens.Spacing.step4))
            .padding(.bottom, CGFloat(SheetValues.overviewTilePadBottom))
            Spacer(minLength: 0)
        }
        .frame(height: CGFloat(size.tileHeight))
        .background(shape.fill(appearance.color(\.well)))
        .ring(shape, entry.current ? appearance.color(\.inkTertiary) : appearance.color(\.line))
        .overlay(alignment: .bottomTrailing) { commands }
        .clipShape(shape)
        .contentShape(shape)
        .background {
            if hot, let layer = Shadows.overviewHoverLight.first {
                shape.inset(by: CGFloat(-layer.spread))
                    .fill(appearance.paint(layer.color))
                    .blur(radius: CGFloat(layer.blur / 2))
                    .offset(x: CGFloat(layer.x), y: CGFloat(layer.y))
            }
        }
        .opacity(entered ? (dimmed ? SheetValues.overviewOtherOpacity : 1) : 0)
        .scaleEffect(entered ? (hot ? SheetValues.overviewHoverScale : dimmed ? SheetValues.overviewOtherScale : 1) : SheetValues.overviewEnterScale)
        .offset(y: entered ? (hot ? -Tokens.Size.overviewHoverLift : 0) : SheetValues.overviewEnterLift)
        .onAppear {
            let delay = Tokens.Duration.overviewDelay + Double(index) * Tokens.Duration.overviewStagger
            withAnimation(appearance.ease(Tokens.Duration.overviewEnter, delay: delay)) { entered = true }
        }
        .onHover { inside in
            if inside { aim(entry.id) } else if hot { aim(nil) }
        }
        .animation(appearance.ease(Tokens.Duration.tileHover), value: hot)
        .animation(appearance.ease(Tokens.Duration.tileHover), value: dimmed)
        .onTapGesture { entry.choose() }
    }

    private var head: some View {
        HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
            Group {
                switch entry.mark {
                case .text(let text): Text(verbatim: text)
                case .icon(let icon): Glyph(icon)
                }
            }
            .designText(size: Tokens.TextSize.small, weight: .medium)
            .frame(width: CGFloat(Tokens.Size.symbolSize), height: CGFloat(Tokens.Size.symbolSize))
            .overlay(Circle().strokeBorder(appearance.color(\.ink).opacity(Tokens.Opacity.ringOnMark), lineWidth: CGFloat(Tokens.Size.hairline)))
            .overlay(alignment: .topTrailing) {
                if entry.unread {
                    Circle().fill(appearance.color(\.ink))
                        .frame(width: CGFloat(Tokens.Spacing.statusDot), height: CGFloat(Tokens.Spacing.statusDot))
                        .background(Circle().fill(appearance.color(\.well)).padding(-CGFloat(Tokens.Size.markSeparatorRing)))
                        .offset(x: CGFloat(SheetValues.unreadDotShift), y: -CGFloat(SheetValues.unreadDotShift))
                }
            }
            .padding(.trailing, CGFloat(Tokens.Spacing.step4))
            entry.title.designText(size: Tokens.TextSize.body, weight: .medium).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            entry.date.designText(\.inkTertiary, size: Tokens.TextSize.small).monospacedDigit().lineLimit(1).fixedSize()
            if let close = entry.close {
                CardHeadButton(help: appearance.string("card.close"), glyph: .close, ink: appearance.color(\.ink), pressed: false, action: close)
            }
        }
        .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
        .frame(height: CGFloat(Tokens.Size.headerHeight))
    }

    @ViewBuilder
    private var commands: some View {
        if !entry.commands.isEmpty {
            HStack(spacing: CGFloat(Tokens.Spacing.step4)) {
                ForEach(entry.commands) { command in
                    SymbolButton(help: command.help, glyph: command.icon, tone: command.tone, hoverTone: command.tone, plate: \.lane,
                                 hover: .fill, action: command.run)
                }
            }
            .padding(CGFloat(Tokens.Spacing.step8))
            .opacity(hot ? 1 : 0)
            .offset(y: hot ? 0 : Tokens.Size.overviewActionsOffset)
            .allowsHitTesting(hot)
            .animation(appearance.ease(Tokens.Duration.tileActions), value: hot)
        }
    }
}
