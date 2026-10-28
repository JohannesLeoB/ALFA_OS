import Design
import SwiftUI

enum Deck {
    static var row: CGFloat { CGFloat(Tokens.Spacing.step44) }

    static var inset: CGFloat { CGFloat(Tokens.Radius.card - Tokens.Size.symbolSize / 2) }

    static var toggleRoom: CGFloat { CGFloat(Tokens.Spacing.step28 + Tokens.Spacing.step20) }

    static func height(_ rows: Int) -> CGFloat { row + row * CGFloat(rows) }

    static func bottomRounded(_ radius: Double) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: CGFloat(radius), bottomTrailingRadius: CGFloat(radius),
                               topTrailingRadius: 0)
    }
}
