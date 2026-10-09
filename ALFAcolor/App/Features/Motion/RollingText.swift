import SwiftUI
import AppTheme
import Motion

/// A line of text whose digits roll to their new value. The rule is in `RollingDigits`.
/// With reduced motion the digits change at once.
struct RollingText: View {
    let text: String
    /// Text style of the line, from the theme.
    var style: TextToken = .body

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let type = theme.text(style)
        let row = type.size * RollingDigits.rowFactor
        let animation = ReplyMotion.roll.animation(reduceMotion: reduceMotion)
        HStack(spacing: 0) {
            ForEach(RollingDigits.slots(for: text), id: \.fromEnd) { slot in
                if let digit = slot.digit {
                    DigitColumn(digit: digit, row: row, font: type.font, animation: animation)
                } else {
                    Text(String(slot.character)).font(type.font)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(text))
    }
}

/// The digits 0 to 9 stacked in a strip. The strip moves to the digit shown, so the old digit rolls to the new one.
private struct DigitColumn: View {
    let digit: Int
    let row: CGFloat
    let font: Font
    let animation: Animation?

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<10, id: \.self) { value in
                Text(String(value))
                    .font(font)
                    .monospacedDigit()
                    .frame(height: row)
            }
        }
        .offset(y: -CGFloat(digit) * row)
        .frame(height: row, alignment: .top)
        .clipped()
        .animation(animation, value: digit)
    }
}
