import SwiftUI

public extension View {
    /// Applies a text style of the theme: font, line spacing and letter spacing.
    func themeText(_ style: TextStyle) -> some View {
        modifier(ThemeTextModifier(style: style))
    }
}

/// Font, line spacing and letter spacing of one text style.
struct ThemeTextModifier: ViewModifier {
    let style: TextStyle

    func body(content: Content) -> some View {
        content
            .font(style.font)
            .lineSpacing(style.lineSpacingPoints)
            .tracking(style.trackingPoints)
    }
}
