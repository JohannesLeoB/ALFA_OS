import Foundation

/// An error while reading a DTCG contract. `path` names the place in the JSON, for example `color.akzent.$value.components[1]`.
public struct DTCGImportError: Error, Equatable, Sendable, CustomStringConvertible {
    public let path: String
    public let message: String
    public init(path: String, message: String) { self.path = path; self.message = message }
    public var description: String { "\(path): \(message)" }
}

/// Reads a DTCG contract into a TokenSet. Scope: format 2025.10 with groups, `$type` inheritance,
/// aliases `{group.token}`, color as an sRGB object, dimensions, durations, curves, fonts and numbers.
/// Source: https://www.designtokens.org/TR/2025.10/format/ and /color/.
/// Values are read from the components. A `hex` is only checked, not used.
public enum DTCGImport {
    public static func tokens(from data: Data, name: String) throws -> TokenSet {
        let root: Any
        do {
            root = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw DTCGImportError(path: "(file)", message: "not valid JSON: \(error.localizedDescription)")
        }
        guard let object = root as? [String: Any] else {
            throw DTCGImportError(path: "(root)", message: "the top level must be an object")
        }
        var leaves: [Leaf] = []
        try collect(object, path: [], inheritedType: nil, into: &leaves)
        let byID = Dictionary(leaves.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let tokens = try leaves
            .sorted { $0.path.lexicographicallyPrecedes($1.path) }
            .map { leaf -> Token in
                let (_, value) = try resolve(leaf.id, byID, chain: [])
                return Token(leaf.path, value, description: leaf.description)
            }
        return TokenSet(name: name, tokens: tokens)
    }

    // MARK: - Collecting the tokens

    /// A token before the aliases are resolved.
    private struct Leaf {
        let path: [String]
        let type: String?
        let value: Any
        let description: String?
        let location: String
        var id: String { path.joined(separator: ".") }
    }

    private static func collect(_ node: [String: Any], path: [String], inheritedType: String?, into leaves: inout [Leaf]) throws {
        let location = path.joined(separator: ".")
        let groupType = try declaredType(node, location) ?? inheritedType
        for name in node.keys.sorted() {
            if name.hasPrefix("$") {
                // Metadata ($type, $description, $deprecated, $extensions) is allowed. $ref is not read,
                // and an object with a $ name would be a token that is otherwise lost silently.
                if name == "$ref" {
                    throw failure(append(location, name), "$ref is not read; write aliases as {group.token}")
                }
                if node[name] is [String: Any], name != "$extensions" {
                    throw failure(append(location, name), "a name must not begin with $")
                }
                continue
            }
            let childPath = path + [name]
            let childLocation = childPath.joined(separator: ".")
            try validateName(name, childLocation)
            guard let child = node[name] as? [String: Any] else {
                throw failure(childLocation, "a group or token must be an object")
            }
            if let value = child["$value"] {
                if child["$ref"] != nil {
                    throw failure(append(childLocation, "$ref"), "$ref is not read; write aliases as {group.token}")
                }
                if let sub = child.keys.sorted().first(where: { !$0.hasPrefix("$") }) {
                    throw failure("\(childLocation).\(sub)", "a token must not have a subgroup")
                }
                let ownType = try declaredType(child, childLocation)
                leaves.append(Leaf(path: childPath,
                                   type: ownType ?? groupType,
                                   value: value,
                                   description: try descriptionText(child, childLocation),
                                   location: childLocation))
            } else {
                try collect(child, path: childPath, inheritedType: groupType, into: &leaves)
            }
        }
    }

    /// DTCG: names must not be empty, must not begin with $ and must not contain dots or curly braces.
    private static func validateName(_ name: String, _ location: String) throws {
        if name.isEmpty || name.contains(where: { ".{}".contains($0) }) {
            throw failure(location, "a name must not be empty and must not contain dots or curly braces")
        }
    }

    private static func declaredType(_ node: [String: Any], _ location: String) throws -> String? {
        guard let raw = node["$type"] else { return nil }
        guard let text = raw as? String else { throw failure(append(location, "$type"), "$type must be a string") }
        return text
    }

    private static func descriptionText(_ node: [String: Any], _ location: String) throws -> String? {
        guard let raw = node["$description"] else { return nil }
        guard let text = raw as? String else { throw failure(append(location, "$description"), "$description must be a string") }
        return text
    }

    // MARK: - Resolving the aliases

    private static func resolve(_ id: String, _ byID: [String: Leaf], chain: [String]) throws -> (type: String, value: TokenValue) {
        guard let leaf = byID[id] else { throw failure(id, "token not found") }
        if let target = aliasTarget(leaf.value) {
            let route = chain + [id]
            if route.contains(target) {
                throw failure(leaf.location + ".$value", "alias loop: " + (route + [target]).joined(separator: " -> "))
            }
            guard byID[target] != nil else {
                throw failure(leaf.location + ".$value", "alias {\(target)} points to no token")
            }
            let (targetType, targetValue) = try resolve(target, byID, chain: route)
            if let own = leaf.type, own != targetType {
                throw failure(append(leaf.location, "$type"), "type \(own) does not match {\(target)} (\(targetType))")
            }
            return (leaf.type ?? targetType, targetValue)
        }
        guard let type = leaf.type else {
            throw failure(leaf.location, "no $type: neither on the token nor on a parent group")
        }
        return (type, try value(leaf.value, type: type, location: leaf.location + ".$value"))
    }

    /// `"{group.token}"` gives `group.token`. Otherwise nil.
    private static func aliasTarget(_ value: Any) -> String? {
        guard let text = value as? String, text.count > 2, text.hasPrefix("{"), text.hasSuffix("}") else { return nil }
        return String(text.dropFirst().dropLast())
    }

    // MARK: - Values by type

    private static func value(_ raw: Any, type: String, location: String) throws -> TokenValue {
        switch type {
        case "color":
            return try color(raw, location)
        case "dimension":
            let (x, unit) = try dimension(raw, location, units: ["px", "rem"])
            return .dimension(x, unit: unit)
        case "duration":
            let (x, unit) = try dimension(raw, location, units: ["ms", "s"])
            return .duration(unit == "s" ? x * 1000 : x)
        case "number":
            return .number(try number(raw, location))
        case "fontFamily":
            if let name = raw as? String { return .fontFamily([name]) }
            if let list = raw as? [Any], !list.isEmpty {
                var names: [String] = []
                for (i, entry) in list.enumerated() {
                    guard let name = entry as? String else {
                        throw failure("\(location)[\(i)]", "font name must be a string")
                    }
                    names.append(name)
                }
                return .fontFamily(names)
            }
            throw failure(location, "fontFamily is a name or a list of names")
        case "fontWeight":
            if let name = raw as? String {
                guard let weight = weightNames[name] else {
                    throw failure(location, "unknown weight name \"\(name)\" (lower-case names such as bold or semi-bold are allowed)")
                }
                return .fontWeight(weight)
            }
            let x = try number(raw, location, 1...1000)
            guard x == x.rounded() else { throw failure(location, "weight must be an integer") }
            return .fontWeight(Int(x))
        case "typography":
            return try typography(raw, location)
        case "cubicBezier":
            guard let parts = raw as? [Any], parts.count == 4 else {
                throw failure(location, "cubicBezier is a list of four numbers")
            }
            var p: [Double] = []
            for (i, part) in parts.enumerated() { p.append(try number(part, "\(location)[\(i)]")) }
            for i in [0, 2] where !(0...1).contains(p[i]) {
                throw failure("\(location)[\(i)]", "x value must be between 0 and 1")
            }
            return .cubicBezier(p[0], p[1], p[2], p[3])
        default:
            throw failure(location, "unknown $type \"\(type)\"")
        }
    }

    /// Weight names according to DTCG 2025.10 (case matters).
    private static let weightNames: [String: Int] = [
        "thin": 100, "hairline": 100,
        "extra-light": 200, "ultra-light": 200,
        "light": 300,
        "normal": 400, "regular": 400, "book": 400,
        "medium": 500,
        "semi-bold": 600, "demi-bold": 600,
        "bold": 700,
        "extra-bold": 800, "ultra-bold": 800,
        "black": 900, "heavy": 900,
        "extra-black": 950, "ultra-black": 950,
    ]

    /// Composite type typography (2025.10, section 9.8): five required properties, font size and letter spacing in px only.
    /// References inside the object are not read; they are refused with their place in the JSON.
    private static func typography(_ raw: Any, _ location: String) throws -> TokenValue {
        guard let o = raw as? [String: Any] else {
            throw failure(location, "typography must be an object with fontFamily, fontSize, fontWeight, letterSpacing and lineHeight")
        }
        for key in ["fontFamily", "fontWeight"] {
            if let text = o[key] as? String, aliasTarget(text) != nil {
                throw failure("\(location).\(key)", "references inside typography are not read; write the value itself")
            }
        }
        guard let family = o["fontFamily"] else { throw failure("\(location).fontFamily", "missing") }
        guard case .fontFamily(let names) = try value(family, type: "fontFamily", location: "\(location).fontFamily") else {
            throw failure("\(location).fontFamily", "fontFamily is a name or a list of names")
        }
        guard let weight = o["fontWeight"] else { throw failure("\(location).fontWeight", "missing") }
        guard case .fontWeight(let w) = try value(weight, type: "fontWeight", location: "\(location).fontWeight") else {
            throw failure("\(location).fontWeight", "fontWeight must be a number or a weight name")
        }
        let (size, _) = try dimension(o["fontSize"] ?? NSNull(), "\(location).fontSize", units: ["px"])
        let (spacing, _) = try dimension(o["letterSpacing"] ?? NSNull(), "\(location).letterSpacing", units: ["px"])
        let height = try number(o["lineHeight"], "\(location).lineHeight")
        return .typography(Typography(fontFamily: names, fontSize: size, fontWeight: w, letterSpacing: spacing, lineHeight: height))
    }

    private static func color(_ raw: Any, _ location: String) throws -> TokenValue {
        guard let o = raw as? [String: Any] else {
            throw failure(location, "color must be an object with colorSpace and components")
        }
        guard let space = o["colorSpace"] as? String else {
            throw failure(location + ".colorSpace", "colorSpace is missing or not a string")
        }
        guard space == "srgb" else {
            throw failure(location + ".colorSpace", "only \"srgb\" is read, found: \"\(space)\"")
        }
        guard let parts = o["components"] as? [Any], parts.count == 3 else {
            throw failure(location + ".components", "components must be a list of three numbers")
        }
        var channels: [Double] = []
        for (i, part) in parts.enumerated() {
            channels.append(try number(part, "\(location).components[\(i)]", 0...1))
        }
        var alpha = 1.0
        if o["alpha"] != nil { alpha = try number(o["alpha"], location + ".alpha", 0...1) }
        if o["hex"] != nil {
            guard let hex = o["hex"] as? String, RGB(hex: hex) != nil else {
                throw failure(location + ".hex", "hex is not a valid color")
            }
        }
        return .color(RGB(r: channels[0], g: channels[1], b: channels[2], a: alpha))
    }

    private static func dimension(_ raw: Any, _ location: String, units: [String]) throws -> (Double, String) {
        guard let o = raw as? [String: Any] else {
            throw failure(location, "dimension must be an object with value and unit")
        }
        let x = try number(o["value"], location + ".value")
        guard let unit = o["unit"] as? String, units.contains(unit) else {
            throw failure(location + ".unit", "unit must be \(units.joined(separator: " or "))")
        }
        return (x, unit)
    }

    /// A number, not a boolean. Optionally within a range.
    private static func number(_ raw: Any?, _ location: String, _ range: ClosedRange<Double>? = nil) throws -> Double {
        guard let raw else { throw failure(location, "missing") }
        guard let n = raw as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() else {
            throw failure(location, "number expected")
        }
        let x = n.doubleValue
        if let range, !range.contains(x) {
            throw failure(location, "\(x) is not between \(range.lowerBound) and \(range.upperBound)")
        }
        return x
    }

    // MARK: - Helpers

    private static func failure(_ path: String, _ message: String) -> DTCGImportError {
        DTCGImportError(path: path.isEmpty ? "(root)" : path, message: message)
    }

    private static func append(_ location: String, _ part: String) -> String {
        location.isEmpty ? part : "\(location).\(part)"
    }
}
