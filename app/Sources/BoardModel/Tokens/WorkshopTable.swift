import Foundation
import ALFAcolorCore
import Tokens

/// The token table: every token of the sets with its type, value in light and dark mode, origin and use.
/// Pure: the caller passes the sets and the space, and the view only shows the rows.
public enum WorkshopTable {
    public struct Row: Equatable, Sendable, Identifiable {
        /// Name of the token set.
        public var tokenSet: String
        public var path: [String]
        /// The DTCG type name, for example "color" or "dimension".
        public var type: String
        /// The light value as text.
        public var light: String
        /// The dark value as text, when a dark set has the same path.
        public var dark: String?
        /// Where the token comes from, when it has a source.
        public var origin: Source?
        /// Pieces of the space that use this colour. Nil for other types, or when no space is given.
        public var uses: Int?

        public var id: String { tokenSet + "/" + path.joined(separator: ".") }
    }

    /// Rows in the order of the light sets. The dark value is the token with the same path in the dark sets.
    public static func rows(light: [TokenSet], dark: [TokenSet] = [], space: Space?) -> [Row] {
        var darkValues: [String: TokenValue] = [:]
        for token in dark.flatMap(\.tokens) {
            darkValues[token.path.joined(separator: ".")] = token.value
        }
        return light.flatMap { set in
            set.tokens.map { token -> Row in
                var uses: Int?
                if case .color(let color) = token.value, space != nil {
                    uses = ColorUse.items(using: color, in: space).count
                }
                return Row(tokenSet: set.name,
                           path: token.path,
                           type: token.value.dtcgType,
                           light: TokenText.value(token.value),
                           dark: darkValues[token.path.joined(separator: ".")].map(TokenText.value),
                           origin: token.source,
                           uses: uses)
            }
        }
    }
}
