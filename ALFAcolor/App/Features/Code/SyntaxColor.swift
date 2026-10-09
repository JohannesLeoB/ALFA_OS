import AppTheme
import Renderers
import SwiftUI

/// The colors of the syntax kinds. The theme has no syntax tokens yet, so the kinds take the colors the theme has.
/// Replace this mapping when the design contract carries syntax colors.
enum SyntaxColor {
    static func color(_ kind: SyntaxKind, theme: Theme, scheme: ColorScheme) -> Color {
        switch kind {
        case .plain, .type: theme.color(.text, scheme)
        case .comment, .attribute: theme.color(.textMuted, scheme)
        case .keyword, .tag: theme.color(.accent, scheme)
        case .string, .number: theme.color(.coral, scheme)
        }
    }
}
