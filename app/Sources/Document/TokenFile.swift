import Foundation
import SetzkastenCore
import Tokens

/// tokens/<satz>.tokens.json: ein Tokensatz als DTCG-Baum (Design Tokens Format Module 2025.10).
///
/// Verlustfrei in beide Richtungen:
/// - Werte stehen mit voller Genauigkeit da (anders als `TokenExport.dtcg`, das Farben auf 4 Stellen rundet).
/// - Herkunft (`Token.source`) und Reihenfolge stehen in `$extensions` unter unserem Namen; fremde Werkzeuge ignorieren das.
/// - Alles, was `TokenSet` nicht abbilden kann (andere Typen, Aliase, Gruppen-`$type`, fremde `$extensions`,
///   unbekannte Schlüssel), bleibt als Rest-Baum erhalten und wird beim Schreiben wieder eingemischt.
enum TokenFile {
    static let namespace = "com.johannesleoberger.setzkasten"

    // MARK: Schreiben

    static func data(for set: TokenSet, extras: [String: JSONValue]) throws -> Data {
        var root: [String: JSONValue] = [:]
        for token in set.tokens {
            try insert(into: &root, path: token.path, leaf: try leaf(for: token), label: token.id)
        }
        if order(of: set.tokens) != sortedOrder(of: set.tokens) {
            let paths = set.tokens.map { JSONValue.array($0.path.map(JSONValue.string)) }
            root["$extensions"] = .object([namespace: .object(["order": .array(paths)])])
        }
        let merged = JSONValue.object(extras).merged(with: .object(root))
        return try PackageJSON.data(merged)
    }

    private static func leaf(for token: Token) throws -> [String: JSONValue] {
        var node: [String: JSONValue] = ["$type": .string(token.value.dtcgType), "$value": value(token.value)]
        if let d = token.description { node["$description"] = .string(d) }
        if let source = token.source {
            let sourceJSON = try PackageJSON.decoder().decode(JSONValue.self, from: PackageJSON.encoder().encode(source))
            node["$extensions"] = .object([namespace: .object(["source": sourceJSON])])
        }
        return node
    }

    private static func value(_ v: TokenValue) -> JSONValue {
        switch v {
        case .color(let c): .object(["colorSpace": .string("srgb"), "components": .array([.double(c.r), .double(c.g), .double(c.b)]),
                                     "alpha": .double(c.a), "hex": .string(String(c.hex.prefix(7)))])
        case .dimension(let x, let unit): .object(["value": .double(x), "unit": .string(unit)])
        case .number(let x): .double(x)
        case .duration(let ms): .object(["value": .double(ms), "unit": .string("ms")])
        case .fontFamily(let f): .array(f.map(JSONValue.string))
        case .fontWeight(let w): .int(w)
        case .cubicBezier(let a, let b, let c, let d): .array([.double(a), .double(b), .double(c), .double(d)])
        }
    }

    private static func insert(into node: inout [String: JSONValue], path: [String], leaf: [String: JSONValue], label: String) throws {
        guard let head = path.first, !head.isEmpty, !head.hasPrefix("$") else { throw PackageError.invalidToken(label) }
        if path.count == 1 {
            guard node[head] == nil else { throw PackageError.invalidToken(label) }
            node[head] = .object(leaf)
            return
        }
        var child: [String: JSONValue]
        switch node[head] {
        case nil: child = [:]
        case .object(let o)?:
            guard o["$value"] == nil else { throw PackageError.invalidToken(label) }   // Blatt und Gruppe am selben Ort
            child = o
        default: throw PackageError.invalidToken(label)
        }
        try insert(into: &child, path: Array(path.dropFirst()), leaf: leaf, label: label)
        node[head] = .object(child)
    }

    private static func order(of tokens: [Token]) -> [[String]] { tokens.map(\.path) }
    private static func sortedOrder(of tokens: [Token]) -> [[String]] { tokens.map(\.path).sorted(by: pathLess) }
    private static func pathLess(_ a: [String], _ b: [String]) -> Bool { a.lexicographicallyPrecedes(b) }

    // MARK: Lesen

    static func parse(_ data: Data, name: String, path: String) throws -> (set: TokenSet, extras: [String: JSONValue]) {
        guard case .object(let root)? = try? PackageJSON.decoder().decode(JSONValue.self, from: data) else {
            throw PackageError.corruptFile(path: path, reason: "kein JSON-Objekt")
        }
        var tokens: [Token] = []
        var extras: [String: JSONValue] = [:]
        var order: [[String]]?
        walk(root, path: [], tokens: &tokens, extras: &extras, order: &order)
        if let order {
            let rank = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
            tokens.sort { a, b in
                switch (rank[a.path], rank[b.path]) {
                case let (x?, y?): x < y
                case (_?, nil): true
                case (nil, _?): false
                default: pathLess(a.path, b.path)
                }
            }
        } else {
            tokens.sort { pathLess($0.path, $1.path) }
        }
        return (TokenSet(name: name, tokens: tokens), extras)
    }

    private static func walk(_ node: [String: JSONValue], path: [String], tokens: inout [Token], extras: inout [String: JSONValue], order: inout [[String]]?) {
        if node["$value"] != nil {
            if let token = token(from: node, path: path, extras: &extras) { tokens.append(token) }
            else { store(.object(node), at: path, in: &extras) }
            return
        }
        for (key, value) in node {
            if key.hasPrefix("$") {
                if path.isEmpty, key == "$extensions", case .object(var ext) = value {
                    if case .object(var ours)? = ext[namespace] {
                        if let o = ours.removeValue(forKey: "order")?.arrayValue {
                            order = o.map { ($0.arrayValue ?? []).compactMap(\.stringValue) }
                        }
                        ext[namespace] = ours.isEmpty ? nil : .object(ours)
                    }
                    if !ext.isEmpty { store(.object(["$extensions": .object(ext)]), at: path, in: &extras) }
                } else {
                    store(.object([key: value]), at: path, in: &extras)
                }
            } else if case .object(let child) = value {
                walk(child, path: path + [key], tokens: &tokens, extras: &extras, order: &order)
            } else {
                store(.object([key: value]), at: path, in: &extras)
            }
        }
    }

    /// Baut ein Blatt, wenn Typ und Wert verstanden werden. Was übrig bleibt (andere `$`-Schlüssel, fremde Erweiterungen), geht in `extras`.
    private static func token(from node: [String: JSONValue], path: [String], extras: inout [String: JSONValue]) -> Token? {
        guard !path.isEmpty, let type = node["$type"]?.stringValue, let raw = node["$value"], let value = parseValue(type: type, raw) else { return nil }
        var rest = node
        for key in ["$type", "$value", "$description"] { rest[key] = nil }
        var source: Source?
        if case .object(var ext)? = rest["$extensions"] {
            if case .object(var ours)? = ext[namespace] {
                if let s = ours.removeValue(forKey: "source"), let d = try? PackageJSON.encoder().encode(s) {
                    source = try? PackageJSON.decoder().decode(Source.self, from: d)
                    if source == nil { ours["source"] = s }   // nicht lesbar: nicht verlieren
                }
                ext[namespace] = ours.isEmpty ? nil : .object(ours)
            }
            rest["$extensions"] = ext.isEmpty ? nil : .object(ext)
        }
        if !rest.isEmpty { store(.object(rest), at: path, in: &extras) }
        return Token(path, value, description: node["$description"]?.stringValue, source: source)
    }

    private static func parseValue(type: String, _ raw: JSONValue) -> TokenValue? {
        switch type {
        case "color":
            if case .string(let s) = raw { return RGB(hex: s).map(TokenValue.color) }
            guard case .object(let o) = raw, o["colorSpace"]?.stringValue == "srgb" else { return nil }
            if let list = o["components"]?.arrayValue {
                let comps = list.compactMap(\.number)
                guard comps.count == 3, list.count == 3 else { return nil }
                return .color(RGB(r: comps[0], g: comps[1], b: comps[2], a: o["alpha"]?.number ?? 1))
            }
            return o["hex"]?.stringValue.flatMap { RGB(hex: $0) }.map(TokenValue.color)
        case "dimension":
            if case .object(let o) = raw, let v = o["value"]?.number, let u = o["unit"]?.stringValue, u == "px" || u == "rem" { return .dimension(v, unit: u) }
            if case .string(let s) = raw {
                for u in ["px", "rem"] where s.hasSuffix(u) { if let v = Double(s.dropLast(u.count)) { return .dimension(v, unit: u) } }
            }
            return nil
        case "number": return raw.number.map(TokenValue.number)
        case "duration":
            guard case .object(let o) = raw, let v = o["value"]?.number, let u = o["unit"]?.stringValue else { return nil }
            switch u { case "ms": return .duration(v); case "s": return .duration(v * 1000); default: return nil }
        case "fontFamily":
            if case .string(let s) = raw { return .fontFamily([s]) }
            guard let a = raw.arrayValue else { return nil }
            let names = a.compactMap(\.stringValue)
            return names.count == a.count ? .fontFamily(names) : nil
        case "fontWeight":
            guard let w = raw.number, w == w.rounded(), abs(w) < 1_000_000 else { return nil }
            return .fontWeight(Int(w))
        case "cubicBezier":
            guard let a = raw.arrayValue?.compactMap(\.number), a.count == 4, raw.arrayValue?.count == 4 else { return nil }
            return .cubicBezier(a[0], a[1], a[2], a[3])
        default: return nil
        }
    }

    /// Legt `value` an `path` im Rest-Baum ab und mischt mit Vorhandenem.
    private static func store(_ value: JSONValue, at path: [String], in tree: inout [String: JSONValue]) {
        var wrapped = value
        for key in path.reversed() { wrapped = .object([key: wrapped]) }
        if case .object(let o) = JSONValue.object(tree).merged(with: wrapped) { tree = o }
    }
}
