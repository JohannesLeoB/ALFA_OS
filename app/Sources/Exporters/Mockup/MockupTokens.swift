import Foundation
import Tokens

/// Finds the tokens that a mockup uses and writes them as DTCG, grouped by token set.
/// A token is used when its CSS variable name occurs in a code card, or when a colour token has the value of a swatch.
struct MockupTokenUse {
    let sets: [TokenSet]
    /// Set name to the IDs of the tokens in use.
    private var used: [String: Set<String>] = [:]

    init(sets: [TokenSet]) {
        self.sets = sets
    }

    /// Records the tokens whose CSS variable name occurs in the text. Returns IDs "set/token".
    mutating func use(in text: String) -> [String] {
        var found: [String] = []
        for set in sets {
            for token in set.tokens where Self.containsVariable(token.path.joined(separator: "-"), in: text) {
                found.append(note(set, token))
            }
        }
        return found
    }

    /// Records the colour tokens with the same hex value as the colour. Returns IDs "set/token".
    mutating func use(color hex: String) -> [String] {
        guard let wanted = RGB(hex: hex).map({ String($0.hex.prefix(7)).uppercased() }) else { return [] }
        var found: [String] = []
        for set in sets {
            for token in set.tokens {
                guard case .color(let rgb) = token.value else { continue }
                if String(rgb.hex.prefix(7)).uppercased() == wanted {
                    found.append(note(set, token))
                }
            }
        }
        return found
    }

    /// The tokens in use, as DTCG JSON: one object per token set, with the set name as key.
    func json() throws -> Data {
        var root: [String: Any] = [:]
        for set in sets {
            let keep = used[set.name] ?? []
            let picked = set.tokens.filter { keep.contains($0.id) }
            guard !picked.isEmpty else { continue }
            let text = try TokenExport.dtcg(TokenSet(name: set.name, tokens: picked))
            root[set.name] = try JSONSerialization.jsonObject(with: Data(text.utf8))
        }
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    }

    private mutating func note(_ set: TokenSet, _ token: Token) -> String {
        used[set.name, default: []].insert(token.id)
        return "\(set.name)/\(token.id)"
    }

    /// True when "--name" occurs in the text and is not the start of a longer name.
    static func containsVariable(_ name: String, in text: String) -> Bool {
        let key = "--" + name
        var start = text.startIndex
        while let range = text.range(of: key, range: start..<text.endIndex) {
            let next = text[range.upperBound...].first
            let ends = next.map { !($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") } ?? true
            if ends { return true }
            start = range.upperBound
        }
        return false
    }
}
