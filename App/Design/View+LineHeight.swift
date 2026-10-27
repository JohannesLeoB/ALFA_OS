import Design
import SwiftUI

extension View {
    func lineHeight(_ height: Double, size: Double, sheet: Bool = false) -> some View {
        let font = sheet ? Typeface.sheet(size: size) : Typeface.font(size: size, weight: Tokens.Weight.regular)
        let natural = font.ascender - font.descender + font.leading
        let gap = max(0, CGFloat(height) - natural)
        return lineSpacing(gap).padding(.vertical, gap / 2)
    }
}
