import Design
import Hub
import SwiftUI

struct AccountCard: View {
    @Environment(\.appearance) private var appearance
    let account: Inlet
    let level: Int
    let last: Bool
    let alert: Bool
    let action: () -> Void
    @State private var hovering = false

    private var step: StackStep {
        let steps = appearance.dark ? Tokens.stackDark : Tokens.stackLight
        return steps[min(level, steps.count - 1)]
    }

    private var gloss: KeyPath<Colors, ColorValue> {
        step.surface.red >= SheetValues.stackGlossLightFrom ? \.stackGlossLight : \.stackGlossDark
    }

    private var shape: UnevenRoundedRectangle {
        let radius = CGFloat(Tokens.Radius.card)
        return UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: radius, bottomTrailingRadius: radius, topTrailingRadius: 0)
    }

    var body: some View {
        let ink = appearance.paint(step.ink)
        let side = CGFloat(Tokens.Size.symbolSize)
        HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
            Text(verbatim: account.mailboxInitials)
                .font(.face(Tokens.TextSize.small, weight: Tokens.Weight.medium))
                .tracking(CGFloat(Tokens.Tracking.mark * Tokens.TextSize.small))
                .lineLimit(1)
                .frame(width: side, height: side)
                .ring(Circle(), ink.opacity(Tokens.Opacity.ringOnMark))
                .overlay(alignment: .topTrailing) { if alert { AccountAlert() } }
                .padding(.trailing, CGFloat(Tokens.Spacing.step12))
            Text(verbatim: account.mailboxName)
                .font(.face(Tokens.TextSize.body, weight: Tokens.Weight.medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(ink)
        .padding(.leading, CGFloat(Tokens.Radius.card - Tokens.Size.symbolSize / 2))
        .padding(.trailing, CGFloat(Tokens.Spacing.step28 + Tokens.Spacing.step20))
        .frame(height: CGFloat(Tokens.Spacing.step44))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(appearance.paint(step.surface))
        .lacquer(shape, gloss: gloss, seam: \.stackSeamBack, drop: !last)
        .contentShape(shape)
        .offset(y: !last && hovering ? CGFloat(SheetValues.stackHoverLift) : 0)
        .onHover { hovering = $0 }
        .onTapGesture(perform: action)
        .help(Text(verbatim: account.account))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .animation(appearance.ease(SheetValues.deckLift, SheetValues.deckSpring), value: hovering)
    }
}
