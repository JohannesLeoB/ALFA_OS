import Foundation

enum ValueParsing {
    static func number(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let value = Double(trimmed), value.isFinite else { return nil }
        return value
    }

    static func length(_ text: String) -> Double? {
        var trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.hasSuffix("px") { trimmed.removeLast(2) }
        return number(trimmed)
    }

    static func em(_ text: String, size: Double) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.hasSuffix("em"), let value = number(String(trimmed.dropLast(2))) { return value * size }
        return length(trimmed)
    }

    static func duration(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.hasSuffix("ms") { return number(String(trimmed.dropLast(2))).map { $0 / 1000 } }
        if trimmed.hasSuffix("s") { return number(String(trimmed.dropLast(1))) }
        return nil
    }

    static func arguments(_ text: String, function: String) -> [Double]? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix(function + "("), trimmed.hasSuffix(")") else { return nil }
        let inner = trimmed.dropFirst(function.count + 1).dropLast()
        let parts = inner.split(separator: ",", omittingEmptySubsequences: false).map { number(String($0)) }
        guard !parts.contains(where: { $0 == nil }) else { return nil }
        return parts.compactMap { $0 }
    }

    static func alias(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("{"), trimmed.hasSuffix("}"), trimmed.count > 2 else { return nil }
        return String(trimmed.dropFirst().dropLast())
    }

    static func color(_ text: String) -> RGB? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("#") { return hex(String(trimmed.dropFirst())) }
        if let parts = arguments(trimmed, function: "rgba"), parts.count == 4 {
            return RGB(parts[0] / 255, parts[1] / 255, parts[2] / 255, parts[3])
        }
        if let parts = arguments(trimmed, function: "rgb"), parts.count == 3 {
            return RGB(parts[0] / 255, parts[1] / 255, parts[2] / 255, 1)
        }
        return nil
    }

    private static func hex(_ digits: String) -> RGB? {
        var chars = Array(digits)
        if chars.count == 3 { chars = chars.flatMap { [$0, $0] } }
        guard chars.count == 6 || chars.count == 8, let raw = UInt64(String(chars), radix: 16) else { return nil }
        let withAlpha = chars.count == 8
        let full = withAlpha ? raw : (raw << 8) | 0xFF
        let channel: (UInt64) -> Double = { Double((full >> $0) & 0xFF) / 255 }
        return RGB(channel(24), channel(16), channel(8), channel(0))
    }

    static func splitTopLevel(_ text: String) -> [String] {
        var parts: [String] = []
        var depth = 0
        var current = ""
        for char in text {
            if char == "(" { depth += 1 }
            if char == ")" { depth -= 1 }
            if char == "," && depth == 0 {
                parts.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        parts.append(current)
        return parts.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    static func shadowLayer(_ text: String, color resolve: (String) -> RGB) -> ShadowLayer? {
        var rest = text.trimmingCharacters(in: .whitespaces)
        var inset = false
        if rest.hasPrefix("inset ") {
            inset = true
            rest = String(rest.dropFirst(6)).trimmingCharacters(in: .whitespaces)
        }
        var numbers: [Double] = []
        while true {
            let head = rest.prefix { $0 != " " }
            guard !head.isEmpty, let value = length(String(head)) else { break }
            numbers.append(value)
            rest = String(rest.dropFirst(head.count)).trimmingCharacters(in: .whitespaces)
        }
        guard (2...4).contains(numbers.count), !rest.isEmpty else { return nil }
        guard color(rest) != nil || alias(rest) != nil else { return nil }
        numbers += Array(repeating: 0, count: 4 - numbers.count)
        return ShadowLayer(inset: inset, x: numbers[0], y: numbers[1], blur: numbers[2], spread: numbers[3], color: resolve(rest))
    }
}
