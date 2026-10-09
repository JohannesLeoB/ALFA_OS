import Foundation

/// Reads the properties of the component of a React card: the destructured parameters that have a default value.
/// The type of a property comes from the parameter's type, the choices from exported arrays and objects, and a
/// range from a comment such as `// 0..100` next to the property. Properties without a default are not controls.
public enum LabPropsReader {
    /// Most controls per component. The first properties win.
    public static let limit = 24

    /// The properties of the component that the source draws, in the order of its parameter list.
    public static func read(_ source: String) -> [LabProp] {
        guard let component = WebDocument.componentName(in: source),
              let parameters = Parameters(component: component, source: source) else { return [] }
        let collections = exportedCollections(in: source)
        var result: [LabProp] = []
        for entry in parameters.entries {
            guard result.count < limit, let prop = prop(entry, declared: parameters.types[entry.name], source: source, collections: collections) else { continue }
            result.append(prop)
        }
        return result
    }

    // MARK: - Properties

    /// One property with its default and its declared type. nil when it has no default that the lab can read.
    static func prop(_ entry: Entry, declared: String?, source: String, collections: [Collection]) -> LabProp? {
        guard let initial = entry.literal else { return nil }
        switch initial {
        case .number(let number):
            let range = rangeComment(for: entry.name, in: source) ?? defaultRange(for: number)
            return LabProp(name: entry.name, kind: .number(range: range.0, step: range.1), initial: .number(number))
        case .flag:
            return LabProp(name: entry.name, kind: .flag, initial: initial)
        case .text(let text):
            if let options = unionChoices(declared) {
                return LabProp(name: entry.name, kind: .choice(options), initial: initial)
            }
            if declared == "number" || declared == "boolean" { return nil }
            if let options = collection(holding: text, named: entry.name, in: collections) {
                return LabProp(name: entry.name, kind: .choice(options), initial: initial)
            }
            return LabProp(name: entry.name, kind: .text, initial: initial)
        }
    }

    /// The slider range and step of a number without a comment: 0 to 100 up to 100, else 0 to twice the default.
    static func defaultRange(for number: Double) -> (ClosedRange<Double>, Double) {
        let top: Double
        if number >= 0 && number <= 100 {
            top = 100
        } else if number > 100 {
            top = 2 * number
        } else {
            return (2 * number...0, step(for: number, top: 0))
        }
        return (0...top, step(for: number, top: top))
    }

    /// Whole numbers move in ones, fractions in hundredths.
    static func step(for number: Double, top: Double) -> Double {
        let whole = number == number.rounded() && top == top.rounded()
        return whole ? 1 : 0.01
    }

    /// The range that a comment next to the property gives, as `0..100`, `0 to 100` or `0 bis 100`. nil without one.
    static func rangeComment(for name: String, in source: String) -> (ClosedRange<Double>, Double)? {
        let lines = source.components(separatedBy: "\n")
        let pattern = try? NSRegularExpression(pattern: "\\b\(name)\\s*[?:=]")
        for (index, line) in lines.enumerated() {
            guard let pattern, pattern.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil else { continue }
            for candidate in [line, index > 0 ? lines[index - 1] : ""] {
                guard let range = rangeText(in: candidate) else { continue }
                let whole = range.lowerBound == range.lowerBound.rounded() && range.upperBound == range.upperBound.rounded()
                return (range, whole ? 1 : 0.01)
            }
        }
        return nil
    }

    static func rangeText(in line: String) -> ClosedRange<Double>? {
        guard let match = line.firstMatch(of: /(-?\d+(?:\.\d+)?)\s*(?:\.\.|to|bis)\s*(-?\d+(?:\.\d+)?)/),
              let low = Double(String(match.output.1)), let high = Double(String(match.output.2)), low <= high else { return nil }
        return low...high
    }

    /// The options of a union of texts in the declared type, such as `"Dots" | "Asterisk"`.
    static func unionChoices(_ declared: String?) -> [String]? {
        guard let declared, declared.contains("|") else { return nil }
        let options = declared.matches(of: /"([^"]*)"|'([^']*)'/).map { String($0.output.1 ?? $0.output.2 ?? "") }
        return options.count > 1 ? options : nil
    }

    /// The exported collection that holds `text`, preferring one whose name goes with the property: `shape` with `SHAPES`.
    static func collection(holding text: String, named name: String, in collections: [Collection]) -> [String]? {
        let holding = collections.filter { $0.options.contains(text) }
        let upper = name.uppercased()
        let preferred = holding.first { [upper, upper + "S", upper + "ES"].contains($0.name) }
        return (preferred ?? holding.first)?.options
    }

    // MARK: - Source

    /// A default value of a parameter: the same cases as the value of a property.
    typealias Literal = LabProp.Value

    /// One destructured parameter: its name, and its default value when the code gives a literal.
    struct Entry {
        let name: String
        let literal: Literal?
    }

    /// An exported array or object of texts, with the texts that it holds: an array's items, or an object's keys.
    struct Collection {
        let name: String
        let options: [String]
    }

    /// The destructured parameter list of a component and the declared types of its properties.
    struct Parameters {
        let entries: [Entry]
        let types: [String: String]

        init?(component: String, source: String) {
            let chars = Array(source)
            guard let open = Parameters.openParenthesis(of: component, in: source),
                  let close = Source.closing(chars, at: open) else { return nil }
            let inside = Array(chars[(open + 1)..<close])
            guard let brace = inside.firstIndex(where: { !$0.isWhitespace }), inside[brace] == "{",
                  let end = Source.closing(inside, at: brace) else { return nil }
            entries = Source.split(String(inside[(brace + 1)..<end]), at: [","]).compactMap(Parameters.entry)
            types = Parameters.types(after: Array(inside[(end + 1)...]), in: source)
        }

        /// The index of the parenthesis that opens the parameter list of a function or an arrow constant.
        static func openParenthesis(of component: String, in source: String) -> Int? {
            let pattern = "(?:function\\s+\(component)\\s*|\\b\(component)\\s*=\\s*(?:async\\s*)?)\\("
            guard let expression = try? NSRegularExpression(pattern: pattern),
                  let match = expression.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)) else { return nil }
            guard let range = Range(match.range, in: source) else { return nil }
            return source.distance(from: source.startIndex, to: range.upperBound) - 1
        }

        static func entry(_ text: String) -> Entry? {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("...") else { return nil }
            let key = trimmed.prefix { $0.isLetter || $0.isNumber || $0 == "_" }
            guard let first = key.first, first.isLetter || first == "_" else { return nil }
            var literal: Literal?
            if let equals = Source.topLevelEquals(in: trimmed) {
                literal = Source.literal(String(trimmed[trimmed.index(after: equals)...]).trimmingCharacters(in: .whitespaces))
            }
            return Entry(name: String(key), literal: literal)
        }

        /// The declared type of each property: from an inline object type, or from a `type` or `interface` of the same name.
        static func types(after rest: [Character], in source: String) -> [String: String] {
            var text = String(rest).trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.hasPrefix(":") else { return [:] }
            text = String(text.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
            if text.hasPrefix("{") {
                return fields(of: text)
            }
            guard let name = text.firstMatch(of: /^[A-Za-z_][A-Za-z0-9_]*/).map({ String($0.output) }),
                  let body = declaredBody(named: name, in: source) else { return [:] }
            return fields(of: body)
        }

        /// The body of `type Name = { ... }` or `interface Name { ... }`, from its opening brace.
        static func declaredBody(named name: String, in source: String) -> String? {
            let pattern = "(?:type\\s+\(name)\\s*=\\s*|interface\\s+\(name)\\s*)\\{"
            guard let expression = try? NSRegularExpression(pattern: pattern),
                  let match = expression.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)) else { return nil }
            let chars = Array(source)
            guard let range = Range(match.range, in: source) else { return nil }
            let open = source.distance(from: source.startIndex, to: range.upperBound) - 1
            guard let close = Source.closing(chars, at: open) else { return nil }
            return String(chars[open...close])
        }

        /// The fields of an object type as `name: type`. Comments and the separators are dropped.
        static func fields(of objectType: String) -> [String: String] {
            var result: [String: String] = [:]
            let inner = objectType.dropFirst().dropLast()
            for line in Source.split(String(inner), at: [";", "\n", ","]) {
                let code = line.components(separatedBy: "//").first ?? ""
                guard let colon = code.firstIndex(of: ":") else { continue }
                let key = code[..<colon].trimmingCharacters(in: CharacterSet(charactersIn: "? \t"))
                let type = code[code.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                if !key.isEmpty, !type.isEmpty { result[key] = type }
            }
            return result
        }
    }

    /// The exported arrays and objects of texts in the source, in source order.
    static func exportedCollections(in source: String) -> [Collection] {
        let chars = Array(source)
        var result: [Collection] = []
        for match in source.matches(of: /export\s+const\s+([A-Za-z_][A-Za-z0-9_]*)[^=\n]*=\s*([\[{])/) {
            let name = String(match.output.1)
            let open = source.distance(from: source.startIndex, to: match.range.upperBound) - 1
            guard let close = Source.closing(chars, at: open) else { continue }
            let inner = String(chars[(open + 1)..<close])
            if chars[open] == "[" {
                let items = Source.split(inner, at: [","]).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                let texts = items.compactMap { item -> String? in
                    guard case .text(let text)? = Source.literal(item) else { return nil }
                    return text
                }
                result.append(Collection(name: name, options: texts))
            } else {
                let keys = Source.split(inner, at: [","]).compactMap { entry -> String? in
                    guard let colon = entry.firstIndex(of: ":") else { return nil }
                    return entry[..<colon].trimmingCharacters(in: CharacterSet(charactersIn: " \t\n\"'"))
                }
                result.append(Collection(name: name, options: keys))
            }
        }
        return result
    }
}

/// Text helpers for the reader: brackets, separators and literals.
enum Source {
    /// The index of the bracket that closes the one at `open`, skipping quoted text. nil when it does not close.
    static func closing(_ chars: [Character], at open: Int) -> Int? {
        guard open < chars.count else { return nil }
        var depth = 0
        var quote: Character?
        var index = open
        while index < chars.count {
            let char = chars[index]
            if let mark = quote {
                if char == "\\" { index += 2; continue }
                if char == mark { quote = nil }
            } else if char == "\"" || char == "'" || char == "`" {
                quote = char
            } else if "([{".contains(char) {
                depth += 1
            } else if ")]}".contains(char) {
                depth -= 1
                if depth == 0 { return index }
            }
            index += 1
        }
        return nil
    }

    /// Splits at the separators that are outside brackets and quotes.
    static func split(_ text: String, at separators: Set<String>) -> [String] {
        var parts: [String] = []
        var current = ""
        var depth = 0
        var quote: Character?
        for char in text {
            if let mark = quote {
                current.append(char)
                if char == mark { quote = nil }
                continue
            }
            if char == "\"" || char == "'" || char == "`" {
                quote = char
            } else if "([{".contains(char) {
                depth += 1
            } else if ")]}".contains(char) {
                depth -= 1
            } else if depth == 0, separators.contains(String(char)) {
                parts.append(current)
                current = ""
                continue
            }
            current.append(char)
        }
        parts.append(current)
        return parts
    }

    /// The position of an `=` that starts a default value, outside brackets, and not part of `==`, `=>` or `<=`.
    static func topLevelEquals(in text: String) -> String.Index? {
        var depth = 0
        var previous: Character?
        var index = text.startIndex
        while index < text.endIndex {
            let char = text[index]
            if "([{".contains(char) { depth += 1 } else if ")]}".contains(char) { depth -= 1 }
            if char == "=", depth == 0, previous != "=", previous != "!", previous != "<", previous != ">" {
                let next = text.index(after: index)
                if next == text.endIndex || (text[next] != "=" && text[next] != ">") { return index }
            }
            previous = char
            index = text.index(after: index)
        }
        return nil
    }

    /// A literal of a default value: a number, true or false, or a quoted text. nil for anything else.
    static func literal(_ text: String) -> LabPropsReader.Literal? {
        let value = text.replacingOccurrences(of: " as const", with: "").trimmingCharacters(in: .whitespaces)
        if value == "true" { return .flag(true) }
        if value == "false" { return .flag(false) }
        if let number = Double(value), value.wholeMatch(of: /-?\d+(?:\.\d+)?/) != nil { return .number(number) }
        if let match = value.wholeMatch(of: /"([^"\\]*)"|'([^'\\]*)'/) {
            return .text(String(match.output.1 ?? match.output.2 ?? ""))
        }
        return nil
    }
}
