import Foundation
import ALFAcolorCore
import Tokens

/// Reads the spacing stops of a document from its token sets.
public enum SpacingTokens {
    /// The dimension tokens in pixels whose path begins with "space". Each stop is named by the token's path,
    /// for example "space.4". Sorted by value, as `Neighbours` needs.
    public static func stops(in sets: [TokenSet]) -> [SpacingStop] {
        sets.flatMap(\.tokens).compactMap { token -> SpacingStop? in
            guard token.path.first == "space", case .dimension(let value, let unit) = token.value,
                  unit == "px", value.isFinite, value >= 0 else { return nil }
            return SpacingStop(name: token.id, value: value)
        }
        .sorted { $0.value < $1.value }
    }
}
