import Design
import Hub
import SwiftUI

struct MailboxGhost: View {
    @Environment(\.appearance) private var appearance
    let account: Inlet
    let level: Int
    let lifted: Bool
    let faded: Bool

    private var step: StackStep {
        let steps = appearance.dark ? Tokens.stackDark : Tokens.stackLight
        return steps[min(level, steps.count - 1)]
    }

    var body: some View {
        let foot = CGFloat(Tokens.Spacing.step44)
        let side = CGFloat(Tokens.Size.symbolSize)
        let shape = RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.card))
        let ink = appearance.paint(step.ink)
        HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
            Text(verbatim: account.mailboxInitials)
                .typeStyle(Tokens.TextStyle.mark)
                .lineLimit(1)
                .frame(width: side, height: side)
                .ring(Circle(), ink.opacity(Tokens.Opacity.ringOnMark))
                .padding(.trailing, CGFloat(Tokens.Spacing.step12))
            Text(verbatim: account.mailboxName)
                .typeStyle(Tokens.TextStyle.bodyEmphasis)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(appearance.color(\.ink))
        .padding(.leading, CGFloat(Tokens.Radius.card - Tokens.Size.symbolSize / 2))
        .padding(.trailing, CGFloat(Tokens.Spacing.step28 + Tokens.Spacing.step20))
        .frame(height: foot)
        .frame(maxWidth: .infinity)
        .animation(appearance.ease(SheetValues.ghostShade, SheetValues.switchInCurve)) {
            $0.background(lifted ? appearance.color(\.lane) : appearance.paint(step.surface), in: shape)
        }
        .animation(appearance.ease(SheetValues.ghostShade, SheetValues.switchInCurve)) {
            $0.shadow(color: lifted ? appearance.color(\.stackFlatFront) : Color.clear,
                      radius: CGFloat(Tokens.Size.stackFlatFrontBlur / 2), y: CGFloat(Tokens.Size.stackFlatFrontOffset))
        }
        .animation(appearance.ease(Tokens.Duration.switchLift, SheetValues.switchOutCurve)) {
            $0.offset(y: lifted ? 0 : foot + foot * CGFloat(level))
        }
        .animation(appearance.ease(SheetValues.ghostFade, SheetValues.switchInCurve, delay: SheetValues.ghostHold)) {
            $0.opacity(faded ? 0 : 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
