import Design
import SwiftUI

struct Counter: View {
    @Environment(\.appearance) private var appearance
    let value: String
    var tone: KeyPath<Colors, ColorValue> = \.inkTertiary
    var ringTone: KeyPath<Colors, ColorValue>?

    var body: some View {
        let ringed = ringTone != nil
        let side = CGFloat(ringed ? Tokens.Size.chipHeight : Tokens.Spacing.step20)
        Text(verbatim: value)
            .typeStyle(Tokens.TextStyle.caption)
            .lineHeight(Tokens.LineHeight.counter * Tokens.TextStyle.caption.size, size: Tokens.TextStyle.caption.size)
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(appearance.color(tone))
            .padding(.horizontal, CGFloat(ringed ? Tokens.Spacing.step8 : Tokens.Spacing.step4))
            .frame(minWidth: side, minHeight: side, maxHeight: side)
            .ring(Pill(), ringTone.map { appearance.color($0) })
    }
}
