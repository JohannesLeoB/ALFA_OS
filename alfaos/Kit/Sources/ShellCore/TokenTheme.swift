import Foundation

public enum TokenThemeError: Error, Equatable {
    case invalidFormat
}

public struct TokenTheme: Sendable {
    private enum Raw: Sendable {
        case text(String)
        case modes([String: String])

        func value(_ mode: TokenMode) -> String? {
            switch self {
            case .text(let text): return text
            case .modes(let table): return table[mode == .light ? "light" : "dark"]
            }
        }
    }

    private let entries: [String: Raw]
    private let styles: [String: TextStyle]

    public init(data: Data) throws {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TokenThemeError.invalidFormat
        }
        var entries: [String: Raw] = [:]
        var styles: [String: TextStyle] = [:]
        for (family, content) in root {
            guard let table = content as? [String: Any] else { continue }
            if family == "type" {
                Self.readType(table, entries: &entries, styles: &styles)
            } else if let tokens = table["tokens"] as? [[String: Any]] {
                for token in tokens {
                    guard let name = token["name"] as? String else { continue }
                    if let text = token["value"] as? String {
                        entries[name] = .text(text)
                    } else if let modes = token["value"] as? [String: String] {
                        entries[name] = .modes(modes)
                    }
                }
            }
        }
        self.entries = entries
        self.styles = styles
    }

    public init(file: URL) throws {
        try self.init(data: Data(contentsOf: file))
    }

    private static func readType(_ table: [String: Any], entries: inout [String: Raw], styles: inout [String: TextStyle]) {
        if let families = table["families"] as? [String: String] {
            for (key, stack) in families { entries["font-" + key] = .text(stack) }
        }
        for group in table["groups"] as? [[String: Any]] ?? [] {
            let groupFamily = group["family"] as? String ?? ""
            for style in group["styles"] as? [[String: Any]] ?? [] {
                guard let name = style["name"] as? String, let size = number(style["fontSize"]) else { continue }
                let tracking = (style["letterSpacing"] as? String).flatMap { ValueParsing.em($0, size: size) } ?? number(style["letterSpacing"]) ?? 0
                styles[name] = TextStyle(
                    size: size,
                    lineHeight: number(style["lineHeight"]) ?? 1,
                    weight: Int(number(style["fontWeight"]) ?? 0),
                    tracking: tracking,
                    family: style["family"] as? String ?? groupFamily
                )
            }
        }
    }

    private static func number(_ value: Any?) -> Double? {
        if let number = value as? Double { return number }
        if let text = value as? String { return ValueParsing.length(text) }
        return nil
    }

    public var missing: [ThemeKey] {
        ThemeKey.all.filter { entries[$0.rawValue] == nil }
    }

    public var missingText: [TextKey] {
        TextKey.all.filter { styles[$0.rawValue] == nil }
    }

    public func has(_ key: ThemeKey) -> Bool { entries[key.rawValue] != nil }

    public func color(_ key: ThemeKey, _ mode: TokenMode) -> RGB {
        resolveColor(key.rawValue, mode, depth: 0)
    }

    private func resolveColor(_ name: String, _ mode: TokenMode, depth: Int) -> RGB {
        guard depth < entries.count + 1, let text = entries[name]?.value(mode) else { return .missing }
        if let target = ValueParsing.alias(text) { return resolveColor(target, mode, depth: depth + 1) }
        return ValueParsing.color(text) ?? .missing
    }

    public func shadow(_ key: ThemeKey, _ mode: TokenMode) -> [ShadowLayer] {
        let missingLayer = ShadowLayer(inset: false, x: 0, y: 0, blur: 0, spread: 1, color: .missing)
        guard let text = entries[key.rawValue]?.value(mode) else { return [missingLayer] }
        if text.trimmingCharacters(in: .whitespaces) == "none" { return [] }
        let layers = ValueParsing.splitTopLevel(text).map { part in
            ValueParsing.shadowLayer(part) { colorText in
                if let target = ValueParsing.alias(colorText) { return resolveColor(target, mode, depth: 0) }
                return ValueParsing.color(colorText) ?? .missing
            }
        }
        if layers.isEmpty || layers.contains(where: { $0 == nil }) { return [missingLayer] }
        return layers.compactMap { $0 }
    }

    private func text(_ key: ThemeKey) -> String? {
        entries[key.rawValue]?.value(.light)
    }

    public func length(_ key: ThemeKey) -> Double {
        text(key).flatMap(ValueParsing.length) ?? 0
    }

    public func number(_ key: ThemeKey) -> Double {
        text(key).flatMap(ValueParsing.number) ?? 0
    }

    public func duration(_ key: ThemeKey) -> Double {
        text(key).flatMap(ValueParsing.duration) ?? 0
    }

    public func curve(_ key: ThemeKey) -> CubicBezier {
        if let parts = text(key).flatMap({ ValueParsing.arguments($0, function: "cubic-bezier") }), parts.count == 4 {
            return CubicBezier(x1: parts[0], y1: parts[1], x2: parts[2], y2: parts[3])
        }
        return CubicBezier(x1: 0, y1: 0, x2: 1, y2: 1)
    }

    public func textStyle(_ key: TextKey) -> TextStyle? {
        styles[key.rawValue]
    }
}
