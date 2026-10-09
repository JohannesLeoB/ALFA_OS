import Foundation
import ALFAcolorCore
import Tokens

/// Colour fields: named colours that live in the token set `colors`.
/// A field is the token at the path ["color", name]. The functions here work on a list of token sets
/// and change nothing else. `BoardStore.changeTokenSets` applies them as one undo step.
public enum ColorFields {
    /// The token set that holds the colour fields.
    public static let setName = "colors"
    /// The first part of the path of a colour field.
    static let group = "color"
    /// The colour of a new field. A neutral grey, to be changed at once.
    public static let defaultColor = RGB(r: 0.5, g: 0.5, b: 0.5)

    /// Why a colour field was refused.
    public enum Failure: Error, Equatable, Sendable {
        case emptyName
        case invalidName(String)
        case duplicateName(String)
        case invalidHex(String)
        case unknownField(String)
    }

    /// A colour field: its name and its colour. A field has no alpha.
    public struct Field: Equatable, Sendable, Identifiable {
        public var name: String
        public var color: RGB
        public var id: String { name }

        public init(name: String, color: RGB) {
            self.name = name
            self.color = color
        }
    }

    /// A colour taken from a picture, with its share of the picture (0 to 1).
    public struct PictureShare: Equatable, Sendable {
        public var color: RGB
        public var share: Double

        public init(color: RGB, share: Double) {
            self.color = color
            self.share = share
        }
    }

    // MARK: Reading

    /// The colour fields in the order of their token set.
    public static func fields(in sets: [TokenSet]) -> [Field] {
        guard let set = sets.first(where: { $0.name == setName }) else { return [] }
        return set.tokens.compactMap { token in
            guard token.path.count == 2, token.path[0] == group, case .color(let color) = token.value else { return nil }
            return Field(name: token.path[1], color: color)
        }
    }

    /// A name that no field uses yet: the base and the lowest free number, for example "Color 2".
    /// The caller gives the base, so that the words of the interface stay in the catalog.
    public static func freeName(base: String, in sets: [TokenSet]) -> String {
        let taken = Set(fields(in: sets).map(\.name))
        var number = 1
        while taken.contains("\(base) \(number)") { number += 1 }
        return "\(base) \(number)"
    }

    /// A colour from a hex text: "#RGB" or "#RRGGBB", with or without "#". Other texts are refused.
    public static func color(hex text: String) throws -> RGB {
        let digits = text.trimmingCharacters(in: .whitespaces).drop(while: { $0 == "#" })
        guard [3, 6].contains(digits.count), digits.allSatisfy(\.isHexDigit), let color = RGB(hex: String(digits)) else {
            throw Failure.invalidHex(text)
        }
        return opaque(color)
    }

    /// A colour from sampled sRGB components (0 to 1). Rounded to whole 8-bit steps, so that the hex is exact.
    public static func sampled(r: Double, g: Double, b: Double) -> RGB {
        func step(_ x: Double) -> Double { (min(max(x, 0), 1) * 255).rounded() / 255 }
        return RGB(r: step(r), g: step(g), b: step(b))
    }

    // MARK: Changing (on a copy of the token sets)

    /// Adds a field. Creates the token set when it is missing. Returns the name as it was stored (trimmed).
    @discardableResult
    public static func add(name raw: String, color: RGB, description: String? = nil, source: Source? = nil, to sets: inout [TokenSet]) throws -> String {
        let name = try checkedName(raw, in: sets, ignoring: nil)
        let token = Token([group, name], .color(opaque(color)), description: description, source: source)
        if let index = sets.firstIndex(where: { $0.name == setName }) {
            sets[index].tokens.append(token)
        } else {
            sets.append(TokenSet(name: setName, tokens: [token]))
        }
        return name
    }

    /// Adds one field per colour taken from a picture, named "base 1", "base 2" … with the lowest free numbers.
    /// Each field keeps its origin: the source is the picture (`via` "image", `file` the asset ID) and the share is its description.
    /// Returns the names in order. Throws at the first refused name; the caller passes a copy, so nothing changes then.
    @discardableResult
    public static func addPictureColors(_ colors: [PictureShare], base: String, assetID: String, importedAt: Date, to sets: inout [TokenSet]) throws -> [String] {
        var names: [String] = []
        for picked in colors {
            let name = freeName(base: base, in: sets)
            let source = Source(file: assetID, via: "image", importedAt: importedAt)
            names.append(try add(name: name, color: picked.color, description: percent(picked.share), source: source, to: &sets))
        }
        return names
    }

    /// Gives a field another name. The new name must be free; the same name is no change.
    public static func rename(_ old: String, to raw: String, in sets: inout [TokenSet]) throws {
        let name = try checkedName(raw, in: sets, ignoring: old)
        let (set, index) = try locate(old, in: sets)
        sets[set].tokens[index].path = [group, name]
    }

    /// Sets the colour of a field.
    public static func setColor(_ name: String, to color: RGB, in sets: inout [TokenSet]) throws {
        let (set, index) = try locate(name, in: sets)
        sets[set].tokens[index].value = .color(opaque(color))
    }

    /// Removes a field. The other fields keep their order.
    public static func remove(_ name: String, from sets: inout [TokenSet]) throws {
        let (set, index) = try locate(name, in: sets)
        sets[set].tokens.remove(at: index)
    }

    // MARK: Helpers

    static func opaque(_ color: RGB) -> RGB { RGB(r: color.r, g: color.g, b: color.b) }

    /// A share as a whole percentage text, for example "23 %".
    static func percent(_ share: Double) -> String { "\(Int((share * 100).rounded())) %" }

    /// The position of a field: the index of its token set and of the token.
    private static func locate(_ name: String, in sets: [TokenSet]) throws -> (set: Int, token: Int) {
        guard let set = sets.firstIndex(where: { $0.name == setName }),
              let token = sets[set].tokens.firstIndex(where: { $0.path == [group, name] }) else {
            throw Failure.unknownField(name)
        }
        return (set, token)
    }

    /// The trimmed name, when it can be a token name and no other field has it. `old` is the field that is renamed, if any.
    static func checkedName(_ raw: String, in sets: [TokenSet], ignoring old: String?) throws -> String {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw Failure.emptyName }
        // The same rule as the DTCG import: a name with a dot or a brace cannot be read back.
        let forbidden = name.hasPrefix("$") || name.contains(where: { ".{}/".contains($0) || $0.isNewline })
        guard !forbidden else { throw Failure.invalidName(name) }
        let others = fields(in: sets).map(\.name).filter { $0 != old }
        guard !others.contains(name) else { throw Failure.duplicateName(name) }
        return name
    }
}
