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
    var still = false
    let aim: (String?) -> Void
    @State private var entered = false

    private var shown: Bool { entered || still }
    private var enterDelay: Double { Double(min(index, SheetValues.overviewStaggerCap)) * SheetValues.overviewTileStagger }
    private var lift: Double { still ? Tokens.Spacing.step2 : Tokens.Size.overviewHoverLift }

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
            .padding(.bottom, CGFloat(Tokens.Spacing.step44))
            Spacer(minLength: 0)
        }
        .frame(height: CGFloat(size.tileHeight))
        .background(shape.fill(appearance.color(\.well)))
        .ring(shape, entry.current ? appearance.color(\.inkTertiary) : appearance.color(\.line))
        .overlay(alignment: .bottomTrailing) { commands }
        .clipShape(shape)
        .contentShape(shape)
        .background {
            if hot, !still, let layer = Shadows.overviewHoverLight.first {
                shape.inset(by: CGFloat(-layer.spread))
                    .fill(appearance.paint(layer.color))
                    .blur(radius: CGFloat(layer.blur / 2))
                    .offset(x: CGFloat(layer.x), y: CGFloat(layer.y))
            }
        }
        .opacity(shown ? (dimmed && !still ? Tokens.Opacity.overviewOther : 1) : 0)
        .animation(appearance.ease(Tokens.Duration.tileHover, SheetValues.cssEase, delay: enterDelay), value: entered)
        .scaleEffect(shown && !still ? (hot ? Tokens.Scale.overviewHot : dimmed ? Tokens.Scale.overviewOther : 1) : 1)
        .offset(y: shown ? (hot ? -lift : 0) : Tokens.Size.overviewTileEnter)
        .animation(appearance.ease(Tokens.Duration.rowSequence, delay: enterDelay), value: entered)
        .onAppear { if !still { entered = true } }
        .onHover { inside in
            if inside { aim(entry.id) } else if hot { aim(nil) }
        }
        .animation(appearance.ease(still ? Tokens.Duration.rowSequence : Tokens.Duration.tileHover), value: hot)
        .animation(appearance.ease(Tokens.Duration.tileHover), value: dimmed)
        .onTapGesture { entry.choose() }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { entry.choose() }
    }

    private var head: some View {
        HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
            Group {
                switch entry.mark {
                case .text(let text): Text(verbatim: text)
                case .icon(let icon): Glyph(icon)
                }
            }
            .typeStyle(Tokens.TextStyle.mark)
            .foregroundStyle(appearance.color(\.ink))
            .frame(width: CGFloat(Tokens.Size.symbolSize), height: CGFloat(Tokens.Size.symbolSize))
            .overlay(Circle().strokeBorder(appearance.color(\.ink).opacity(Tokens.Opacity.ringOnMark), lineWidth: CGFloat(Tokens.Size.hairline)))
            .overlay(alignment: .topTrailing) {
                if entry.unread {
                    Circle().fill(appearance.color(\.ink))
                        .frame(width: CGFloat(Tokens.Spacing.step8), height: CGFloat(Tokens.Spacing.step8))
                        .background(Circle().fill(appearance.color(\.well)).padding(-CGFloat(Tokens.Size.markSeparatorRing)))
                        .offset(x: CGFloat(Tokens.Spacing.step2), y: -CGFloat(Tokens.Spacing.step2))
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
            .animation(appearance.ease(Tokens.Duration.chevron, SheetValues.cssEase), value: hot)
            .offset(y: hot ? 0 : Tokens.Size.overviewActionsOffset)
            .animation(appearance.ease(Tokens.Duration.tileHover), value: hot)
            .allowsHitTesting(hot)
        }
    }
}
