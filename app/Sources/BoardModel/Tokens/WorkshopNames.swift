import Foundation
import Tokens

/// Name suggestions for tokens: color.<n> from the lightest colour, space.<n> for pixel values that are
/// multiples of 4 (16 gives space.4), radius.<name> from the smallest radius (s, m, l, then numbers),
/// and text.<step> for the steps of a type ramp. A suggestion is only a proposal; the caller accepts each one.
public enum WorkshopNames {
    /// A proposed path for one token of a set.
    public struct Suggestion: Equatable, Sendable, Identifiable {
        /// Name of the token set.
        public var tokenSet: String
        /// The current path of the token.
        public var from: [String]
        /// The proposed path.
        public var to: [String]

        public var id: String { tokenSet + "/" + from.joined(separator: ".") }
    }

    /// Why a suggestion was not accepted.
    public enum Failure: Error, Equatable, Sendable {
        case unknownToken([String])
        case taken(String)
    }

    /// Suggestions for one set, in a fixed order. A token whose proposal is its own path gets none,
    /// and a proposal that another token or an earlier suggestion already uses is left out.
    public static func suggestions(in set: TokenSet) -> [Suggestion] {
        var proposals: [(index: Int, path: [String])] = []

        let colours = set.tokens.indices.filter { isColour(set.tokens[$0].value) }
        for (number, index) in colours.sorted(by: { luminance(set.tokens[$0].value) > luminance(set.tokens[$1].value) }).enumerated() {
            proposals.append((index, ["color", "\(number + 1)"]))
        }

        let radii = set.tokens.indices.filter { set.tokens[$0].path.first == "radius" && pixels(set.tokens[$0].value) != nil }
        let radiusNames = ["s", "m", "l"]
        for (number, index) in radii.sorted(by: { (pixels(set.tokens[$0].value) ?? 0) < (pixels(set.tokens[$1].value) ?? 0) }).enumerated() {
            let name = number < radiusNames.count ? radiusNames[number] : "\(number + 1)"
            proposals.append((index, ["radius", name]))
        }

        for index in set.tokens.indices where set.tokens[index].path.first != "radius" {
            guard let x = pixels(set.tokens[index].value), x > 0, x.truncatingRemainder(dividingBy: 4) == 0 else { continue }
            proposals.append((index, ["space", "\(Int(x / 4))"]))
        }

        for index in set.tokens.indices {
            guard let mark = set.tokens[index].ramp else { continue }
            proposals.append((index, ["text", mark.step.rawValue]))
        }

        var taken = Set(set.tokens.map { $0.path.joined(separator: ".") })
        var out: [Suggestion] = []
        for proposal in proposals {
            let token = set.tokens[proposal.index]
            let key = proposal.path.joined(separator: ".")
            guard token.path != proposal.path, !taken.contains(key) else { continue }
            taken.insert(key)
            out.append(Suggestion(tokenSet: set.name, from: token.path, to: proposal.path))
        }
        return out
    }

    /// Renames the token as suggested. The new path must be free; otherwise nothing changes and the call throws.
    public static func accept(_ suggestion: Suggestion, in sets: inout [TokenSet]) throws {
        guard let set = sets.firstIndex(where: { $0.name == suggestion.tokenSet }),
              let token = sets[set].tokens.firstIndex(where: { $0.path == suggestion.from }) else {
            throw Failure.unknownToken(suggestion.from)
        }
        let key = suggestion.to.joined(separator: ".")
        guard !sets[set].tokens.contains(where: { $0.path.joined(separator: ".") == key }) else {
            throw Failure.taken(key)
        }
        sets[set].tokens[token].path = suggestion.to
    }

    // MARK: Helpers

    private static func isColour(_ value: TokenValue) -> Bool {
        if case .color = value { return true }
        return false
    }

    /// Pixel value of a dimension, nil for other values and for rem.
    private static func pixels(_ value: TokenValue) -> Double? {
        guard case .dimension(let x, let unit) = value, unit == "px" else { return nil }
        return x
    }

    /// Relative brightness of a colour, for ordering only. Other values give zero.
    private static func luminance(_ value: TokenValue) -> Double {
        guard case .color(let c) = value else { return 0 }
        return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
    }
}
