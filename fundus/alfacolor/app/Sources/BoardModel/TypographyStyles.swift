import Foundation
import ALFAcolorCore
import Tokens

/// Text styles: `typography` tokens at ["type", name] in the token set `text`. The type ramp is part of them.
/// The functions work on a list of token sets and change nothing else. `BoardStore` applies them as one undo step.
public enum TypographyStyles {
    /// The token set that holds the text styles.
    public static let setName = TypeRamp.setName
    /// The first part of the path of a text style.
    public static let group = TypeRamp.group

    /// Why a text style or the ramp was refused.
    public enum Failure: Error, Equatable, Sendable {
        case emptyName
        case invalidName(String)
        case duplicateName(String)
        case unknownStyle(String)
        case invalidNumber(String)
        case noRamp
    }

    /// A text style: its name and its values. The ramp mark is set for the six steps of the ramp.
    public struct Style: Equatable, Sendable, Identifiable {
        public var name: String
        public var style: Typography
        public var ramp: RampMark?
        public var id: String { name }

        public init(name: String, style: Typography, ramp: RampMark? = nil) {
            self.name = name; self.style = style; self.ramp = ramp
        }
    }

    // MARK: Reading

    /// The text styles in the order of their token set.
    public static func styles(in sets: [TokenSet]) -> [Style] {
        guard let set = sets.first(where: { $0.name == setName }) else { return [] }
        return set.tokens.compactMap { token in
            guard token.path.count == 2, token.path[0] == group, case .typography(let style) = token.value else { return nil }
            return Style(name: token.path[1], style: style, ramp: token.ramp)
        }
    }

    // MARK: Changing (on a copy of the token sets)

    /// Adds a text style. Creates the token set when it is missing. Returns the name as stored (trimmed).
    @discardableResult
    public static func add(name raw: String, style: Typography, to sets: inout [TokenSet]) throws -> String {
        let name = try checkedName(raw, in: sets, ignoring: nil)
        try check(style)
        let token = Token([group, name], .typography(style))
        if let index = sets.firstIndex(where: { $0.name == setName }) {
            sets[index].tokens.append(token)
        } else {
            sets.append(TokenSet(name: setName, tokens: [token]))
        }
        return name
    }

    /// Sets the values of a text style. A ramp step whose size changes by hand is marked as typed.
    public static func change(_ name: String, to style: Typography, in sets: inout [TokenSet]) throws {
        try check(style)
        let (set, index) = try locate(name, in: sets)
        var token = sets[set].tokens[index]
        guard case .typography(let before) = token.value else { throw Failure.unknownStyle(name) }
        if var mark = token.ramp, before.fontSize != style.fontSize {
            mark.overridden = true
            token.ramp = mark
        }
        token.value = .typography(style)
        sets[set].tokens[index] = token
    }

    /// Sets the licence text of a text style, kept as the token description. Empty text removes it.
    public static func setLicense(_ name: String, to text: String, in sets: inout [TokenSet]) throws {
        let (set, index) = try locate(name, in: sets)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        sets[set].tokens[index].description = trimmed.isEmpty ? nil : trimmed
    }

    /// Removes a text style. The other styles keep their order.
    public static func remove(_ name: String, from sets: inout [TokenSet]) throws {
        let (set, index) = try locate(name, in: sets)
        sets[set].tokens.remove(at: index)
    }

    /// Creates the six steps of the ramp from a spec. Ramp steps that exist are replaced; other styles stay.
    public static func makeRamp(_ spec: TypeRampSpec, in sets: inout [TokenSet]) throws {
        try checkRamp(base: spec.base, factor: spec.factor)
        let ramp = TypeRamp.tokens(spec)
        let names = Set(ramp.map(\.path))
        for name in ramp.map({ $0.path[1] }) where sets.contains(where: { $0.name == setName && $0.tokens.contains { $0.path == [group, name] && $0.ramp == nil } }) {
            throw Failure.duplicateName(name)
        }
        if let index = sets.firstIndex(where: { $0.name == setName }) {
            sets[index].tokens.removeAll { names.contains($0.path) }
            sets[index].tokens.append(contentsOf: ramp)
        } else {
            sets.append(TokenSet(name: setName, tokens: ramp))
        }
    }

    /// Calculates the ramp again from a new base and factor. Steps whose size was set by hand keep it.
    public static func recalculate(base: Double, factor: Double, in sets: inout [TokenSet]) throws {
        try checkRamp(base: base, factor: factor)
        guard let index = sets.firstIndex(where: { $0.name == setName }),
              sets[index].tokens.contains(where: { $0.ramp != nil }) else { throw Failure.noRamp }
        sets[index].tokens = TypeRamp.recalculate(sets[index].tokens, base: base, factor: factor)
    }

    // MARK: Helpers

    /// The position of a text style: the index of its token set and of the token.
    private static func locate(_ name: String, in sets: [TokenSet]) throws -> (set: Int, token: Int) {
        guard let set = sets.firstIndex(where: { $0.name == setName }),
              let token = sets[set].tokens.firstIndex(where: { $0.path == [group, name] }) else {
            throw Failure.unknownStyle(name)
        }
        return (set, token)
    }

    /// The trimmed name, when it can be a token name and no other text style has it.
    static func checkedName(_ raw: String, in sets: [TokenSet], ignoring old: String?) throws -> String {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw Failure.emptyName }
        // The same rule as the DTCG import: a name with a dot or a brace cannot be read back.
        let forbidden = name.hasPrefix("$") || name.contains(where: { ".{}/".contains($0) || $0.isNewline })
        guard !forbidden else { throw Failure.invalidName(name) }
        let others = styles(in: sets).map(\.name).filter { $0 != old }
        guard !others.contains(name) else { throw Failure.duplicateName(name) }
        return name
    }

    /// Sizes, weights and line heights must be positive numbers in their range.
    static func check(_ style: Typography) throws {
        guard !style.fontFamily.isEmpty else { throw Failure.invalidNumber("fontFamily") }
        guard style.fontSize.isFinite, style.fontSize > 0 else { throw Failure.invalidNumber("fontSize") }
        guard (1...1000).contains(style.fontWeight) else { throw Failure.invalidNumber("fontWeight") }
        guard style.letterSpacing.isFinite else { throw Failure.invalidNumber("letterSpacing") }
        guard style.lineHeight.isFinite, style.lineHeight > 0 else { throw Failure.invalidNumber("lineHeight") }
    }

    static func checkRamp(base: Double, factor: Double) throws {
        guard base.isFinite, base > 0 else { throw Failure.invalidNumber("base") }
        guard factor.isFinite, factor > 0 else { throw Failure.invalidNumber("factor") }
    }
}
