import Foundation
import ALFAcolorCore

/// Color in sRGB, channels 0...1.
public struct RGB: Codable, Hashable, Sendable {
    public var r: Double, g: Double, b: Double, a: Double = 1
    public init(r: Double, g: Double, b: Double, a: Double = 1) { self.r = r; self.g = g; self.b = b; self.a = a }
    public init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        guard s.count == 6 || s.count == 8, let v = UInt64(s, radix: 16) else { return nil }
        let full = s.count == 6 ? (v << 8) | 0xFF : v
        r = Double((full >> 24) & 0xFF) / 255; g = Double((full >> 16) & 0xFF) / 255
        b = Double((full >> 8) & 0xFF) / 255; a = Double(full & 0xFF) / 255
    }
    public var hex: String {
        func h(_ x: Double) -> String {
            let clamped = x.isNaN ? 0 : min(max(x, 0), 1)
            return String(format: "%02X", Int((clamped * 255).rounded()))
        }
        return "#" + h(r) + h(g) + h(b) + (a < 1 ? h(a) : "")
    }
}

/// A text style: the composite token type `typography`.
/// Source: Design Tokens Format Module 2025.10, section 9.8 (https://www.designtokens.org/TR/2025.10/format/#typography).
/// The five properties are all required. Font size and letter spacing are in px. The line height is a multiplier of the font size.
public struct Typography: Codable, Hashable, Sendable {
    public var fontFamily: [String]
    public var fontSize: Double
    public var fontWeight: Int
    public var letterSpacing: Double
    public var lineHeight: Double
    public init(fontFamily: [String], fontSize: Double, fontWeight: Int, letterSpacing: Double, lineHeight: Double) {
        self.fontFamily = fontFamily; self.fontSize = fontSize; self.fontWeight = fontWeight
        self.letterSpacing = letterSpacing; self.lineHeight = lineHeight
    }
}

/// Token kinds according to the Design Tokens Format Module 2025.10 of the W3C Community Group (DTCG; community report, not a W3C standard).
public enum TokenValue: Codable, Hashable, Sendable {
    case color(RGB)
    case dimension(Double, unit: String)      // "px" or "rem"
    case number(Double)
    case duration(Double)                     // milliseconds
    case fontFamily([String])
    case fontWeight(Int)
    case cubicBezier(Double, Double, Double, Double)
    case typography(Typography)
    public var dtcgType: String {
        switch self {
        case .color: "color"; case .dimension: "dimension"; case .number: "number"; case .duration: "duration"
        case .fontFamily: "fontFamily"; case .fontWeight: "fontWeight"; case .cubicBezier: "cubicBezier"
        case .typography: "typography"
        }
    }
}

/// A token. path = groups and name, for example ["color", "accent"].
public struct Token: Codable, Hashable, Sendable, Identifiable {
    public var path: [String]
    public var value: TokenValue
    public var description: String?
    public var source: Source?
    /// Set for the steps of a type ramp (see `TypeRamp`); nil for every other token.
    public var ramp: RampMark?
    public var id: String { path.joined(separator: ".") }
    public init(_ path: [String], _ value: TokenValue, description: String? = nil, source: Source? = nil, ramp: RampMark? = nil) {
        self.path = path; self.value = value; self.description = description; self.source = source; self.ramp = ramp
    }
}

public struct TokenSet: Codable, Hashable, Sendable {
    public var name: String
    public var tokens: [Token]
    public init(name: String, tokens: [Token]) { self.name = name; self.tokens = tokens }
}

// MARK: - Output

public enum TokenExport {
    /// DTCG JSON. Form of the values according to specification 2025.10 (objects for color, dimension, duration).
    /// Source: https://www.designtokens.org/TR/2025.10/format/ and /color/. Older tools expect strings such as "16px".
    public static func dtcg(_ set: TokenSet) throws -> String {
        var root: [String: Any] = [:]
        for t in set.tokens {
            var leaf: [String: Any] = ["$type": t.value.dtcgType, "$value": dtcgValue(t.value)]
            if let d = t.description { leaf["$description"] = d }
            insert(&root, path: t.path, leaf: leaf)
        }
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }
    static func dtcgValue(_ v: TokenValue) -> Any {
        switch v {
        case .color(let c):
            return ["colorSpace": "srgb", "components": [round4(c.r), round4(c.g), round4(c.b)], "alpha": round4(c.a), "hex": String(c.hex.prefix(7))]
        case .dimension(let x, let unit): return ["value": x, "unit": unit]
        case .number(let x): return x
        case .duration(let ms): return ["value": ms, "unit": "ms"]
        case .fontFamily(let f): return f
        case .fontWeight(let w): return w
        case .cubicBezier(let a, let b, let c, let d): return [a, b, c, d]
        case .typography(let t):
            return ["fontFamily": t.fontFamily, "fontSize": ["value": t.fontSize, "unit": "px"],
                    "fontWeight": t.fontWeight, "letterSpacing": ["value": t.letterSpacing, "unit": "px"],
                    "lineHeight": t.lineHeight]
        }
    }
    static func round4(_ x: Double) -> Double { (x * 10000).rounded() / 10000 }
    static func insert(_ node: inout [String: Any], path: [String], leaf: [String: Any]) {
        guard let head = path.first else { return }
        if path.count == 1 { node[head] = leaf; return }
        var child = node[head] as? [String: Any] ?? [:]
        insert(&child, path: Array(path.dropFirst()), leaf: leaf)
        node[head] = child
    }

    /// CSS variables on :root. Name: the path joined with hyphens.
    /// A typography token gives one variable per property: `--<name>-font-family`, `-font-size`, `-font-weight`, `-letter-spacing`, `-line-height`.
    public static func css(_ set: TokenSet) -> String {
        let lines = set.tokens.flatMap { token -> [String] in
            let name = token.path.joined(separator: "-")
            guard case .typography(let t) = token.value else { return ["  --\(name): \(cssValue(token.value));"] }
            return ["  --\(name)-font-family: \(cssValue(.fontFamily(t.fontFamily)));",
                    "  --\(name)-font-size: \(fmt(t.fontSize))px;",
                    "  --\(name)-font-weight: \(t.fontWeight);",
                    "  --\(name)-letter-spacing: \(fmt(t.letterSpacing))px;",
                    "  --\(name)-line-height: \(fmt(t.lineHeight));"]
        }
        return ":root {\n" + lines.joined(separator: "\n") + "\n}\n"
    }
    static func cssValue(_ v: TokenValue) -> String {
        switch v {
        case .color(let c): c.hex
        case .dimension(let x, let unit): fmt(x) + unit
        case .number(let x): fmt(x)
        case .duration(let ms): fmt(ms) + "ms"
        case .fontFamily(let f): f.map { $0.contains(" ") ? "\"\($0)\"" : $0 }.joined(separator: ", ")
        case .fontWeight(let w): String(w)
        case .cubicBezier(let a, let b, let c, let d): "cubic-bezier(\(fmt(a)), \(fmt(b)), \(fmt(c)), \(fmt(d)))"
        case .typography(let t): cssValue(.fontFamily(t.fontFamily))
        }
    }

    /// SwiftUI source: an enum with static values. Dimensions in points (px = pt at @1x).
    public static func swiftUI(_ set: TokenSet, typeName: String = "Tokens") -> String {
        var out = "import SwiftUI\n\n/// Generated by ALFAcolor from the set \"\(set.name.components(separatedBy: .newlines).joined(separator: " "))\". Do not edit by hand.\n"
        if set.tokens.contains(where: { if case .typography = $0.value { true } else { false } }) {
            out += typeStyleDeclaration
        }
        out += "public enum \(typeName) {\n"
        for t in set.tokens {
            let name = camel(t.path)
            switch t.value {
            case .color(let c): out += "    public static let \(name) = Color(.sRGB, red: \(fmt(c.r, 4)), green: \(fmt(c.g, 4)), blue: \(fmt(c.b, 4)), opacity: \(fmt(c.a, 4)))\n"
            case .dimension(let x, let unit): out += "    public static let \(name): CGFloat = \(fmt(unit == "rem" ? x * 16 : x))\n"
            case .number(let x): out += "    public static let \(name): Double = \(fmt(x))\n"
            case .duration(let ms): out += "    public static let \(name): Double = \(fmt(ms / 1000, 3)) // seconds\n"
            case .fontFamily(let f): out += "    public static let \(name) = \"\(swiftEscape(f.first ?? ""))\"\n"
            case .fontWeight(let w): out += "    public static let \(name) = Font.Weight.\(weightName(w))\n"
            case .cubicBezier(let a, let b, let c, let d): out += "    public static let \(name) = UnitCurve.bezier(startControlPoint: UnitPoint(x: \(fmt(a)), y: \(fmt(b))), endControlPoint: UnitPoint(x: \(fmt(c)), y: \(fmt(d))))\n"
            case .typography(let t):
                let families = t.fontFamily.map { "\"\(swiftEscape($0))\"" }.joined(separator: ", ")
                out += "    public static let \(name) = TypeStyle(families: [\(families)], size: \(fmt(t.fontSize)), weight: \(t.fontWeight), "
                    + "lineHeight: \(fmt(t.lineHeight, 4)), letterSpacing: \(fmt(t.letterSpacing)))\n"
            }
        }
        return out + "}\n"
    }
    /// The struct that holds one text style in the generated source. Written only when the set has a text style.
    /// Source of the names: Design Tokens Format Module 2025.10, section 9.8 (typography).
    static let typeStyleDeclaration = """
    /// A text style: families, size and weight in points, line height as a multiplier, letter spacing in points.
    public struct TypeStyle: Sendable, Equatable {
        public let families: [String]
        public let size: CGFloat
        public let weight: Int
        public let lineHeight: Double
        public let letterSpacing: CGFloat

        public init(families: [String], size: CGFloat, weight: Int, lineHeight: Double, letterSpacing: CGFloat) {
            self.families = families; self.size = size; self.weight = weight
            self.lineHeight = lineHeight; self.letterSpacing = letterSpacing
        }
    }


    """

    /// A text for a Swift string literal: backslash and double quote escaped.
    static func swiftEscape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }

    static func weightName(_ w: Int) -> String {
        switch w { case ..<150: "ultraLight"; case ..<250: "thin"; case ..<350: "light"; case ..<450: "regular"; case ..<550: "medium"; case ..<650: "semibold"; case ..<750: "bold"; case ..<850: "heavy"; default: "black" }
    }
    static func camel(_ path: [String]) -> String {
        let parts = path.flatMap { $0.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init) }
        guard let first = parts.first else { return "token" }
        let name = first.lowercased() + parts.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
        return name.first?.isNumber == true ? "t" + name : name
    }
    static func fmt(_ x: Double, _ digits: Int = 2) -> String {
        if x.isFinite, abs(x) < 1e15, x == x.rounded() { return String(Int(x)) }
        var s = String(format: "%.\(digits)f", x)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }
}

// MARK: - Create and unify

public enum TokenTools {
    /// Size scale for type: base times ratio to the power of the step, rounded to whole points.
    /// Example: base 16, ratio 1.25, steps -2...4.
    public static func typeScale(base: Double, ratio: Double, steps: ClosedRange<Int>) -> [Int: Double] {
        var out: [Int: Double] = [:]
        for s in steps { out[s] = (base * pow(ratio, Double(s))).rounded() }
        return out
    }
    /// Spacing scale on a grid, for example step 4: 4, 8, 12, 16, 24, 32, 48, 64.
    public static func spacingScale(step: Double, multipliers: [Double] = [1, 2, 3, 4, 6, 8, 12, 16]) -> [Double] {
        multipliers.map { $0 * step }
    }
    /// Unify: pull collected dimensions to the nearest grid value and merge them.
    /// Result: target value to the raw values that were pulled there. This keeps every change visible.
    public static func unifyDimensions(_ raw: [Double], step: Double) -> [Double: [Double]] {
        var out: [Double: [Double]] = [:]
        for v in raw { out[(v / step).rounded() * step, default: []].append(v) }
        return out
    }
}
