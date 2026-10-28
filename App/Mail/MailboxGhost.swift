import Design
import Hub
import SwiftUI

struct MailboxGhost: View {
    @Environment(\.appearance) private var appearance
    let account: Inlet
    let display: MailboxDisplay
    let level: Int
    let lifted: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.card))
        let ink = appearance.color(\.ink)
        MailboxRow(account: account, display: display, ink: ink, trailing: Deck.inset)
            .foregroundStyle(ink)
            .frame(maxWidth: .infinity)
            .animation(appearance.ease(Tokens.Duration.switchFade, Tokens.Easing.glassIn)) {
                $0.background(lifted ? appearance.color(\.lane) : appearance.paint(appearance.stackStep(level).surface), in: shape)
            }
            .animation(appearance.ease(Tokens.Duration.switchFade, Tokens.Easing.glassIn)) {
                $0.ring(shape, appearance.color(lifted ? \.line : \.ghostRing))
                    .background {
                        shape.inset(by: CGFloat(-Tokens.Size.ghostShadowSpread))
                            .fill(lifted ? appearance.color(\.ghostShadow) : Color.clear)
                            .blur(radius: CGFloat(Tokens.Size.ghostShadowBlur / 2))
                            .offset(y: CGFloat(Tokens.Size.ghostShadowOffset))
                    }
            }
            .animation(appearance.ease(Tokens.Duration.switchLift, Tokens.Easing.glassOut)) {
                $0.offset(y: lifted ? 0 : Deck.height(level))
            }
            .animation(appearance.ease(Tokens.Duration.switchGhostFade, Tokens.Easing.glassIn, delay: Tokens.Duration.switchFade)) {
                $0.opacity(lifted ? 0 : 1)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
