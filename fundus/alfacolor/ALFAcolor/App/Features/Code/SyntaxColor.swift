import AppTheme
import CodePlayer
import SwiftUI

/// The colors of the syntax kinds, from the syntax tokens of the design contract.
enum SyntaxColor {
    static func color(_ kind: SyntaxKind, theme: Theme, scheme: ColorScheme) -> Color {
        switch kind {
        case .plain: theme.color(.text, scheme)
        case .type, .attribute: theme.color(.synType, scheme)
        case .comment: theme.color(.synComment, scheme)
        case .keyword: theme.color(.synKeyword, scheme)
        case .tag: theme.color(.synTag, scheme)
        case .string: theme.color(.synString, scheme)
        case .number: theme.color(.synNumber, scheme)
        }
    }
}
