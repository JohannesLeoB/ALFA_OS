import Foundation

/// Tells whether a text is style sheet code and nothing else: rules with declarations, at-rules, and nested rules.
/// It checks the shape, not the values. Script code and JSON do not pass.
enum CSSShape {
    /// Words that start a statement of script code. A rule never starts with one.
    private static let scriptWords: Set<String> = ["if", "for", "while", "switch", "function", "class", "else", "try", "catch", "do", "with", "return"]

    static func isStyleSheet(_ text: String) -> Bool {
        var scanner = Scanner(chars: Array(withoutComments(text)))
        guard let count = scanner.parseBody(nested: false), count > 0 else { return false }
        return scanner.atEnd
    }

    private static func withoutComments(_ text: String) -> String {
        var out = ""
        var rest = Substring(text)
        while let open = rest.range(of: "/*") {
            out += rest[..<open.lowerBound]
            guard let close = rest.range(of: "*/", range: open.upperBound..<rest.endIndex) else { return out }
            rest = rest[close.upperBound...]
        }
        return out + rest
    }

    private struct Scanner {
        let chars: [Character]
        var index = 0
        var atEnd: Bool { index >= chars.count }

        init(chars: [Character]) { self.chars = chars }

        /// Reads rules and declarations up to the end of the text or, when nested, up to the closing brace.
        /// Returns how many rules and declarations it found, or nil when the text is not style code.
        mutating func parseBody(nested: Bool) -> Int? {
            var found = 0
            while true {
                skipSpace()
                if atEnd { return nested ? nil : found }
                if chars[index] == "}" {
                    guard nested else { return nil }
                    index += 1
                    return found
                }
                guard let (prelude, end) = readPrelude() else { return nil }
                switch end {
                case "{":
                    guard isSelectorOrAtRule(prelude) else { return nil }
                    index += 1
                    guard let inner = parseBody(nested: true) else { return nil }
                    found += max(inner, 1)
                case ";":
                    guard nested ? isDeclaration(prelude) : prelude.hasPrefix("@") else { return nil }
                    index += 1
                    found += 1
                default:
                    // The last declaration of a body may leave out the semicolon.
                    guard nested, isDeclaration(prelude) else { return nil }
                    found += 1
                }
            }
        }

        private mutating func skipSpace() {
            while index < chars.count, chars[index].isWhitespace { index += 1 }
        }

        /// The text up to the next `{`, `;` or `}` outside of parentheses, brackets and quotes. The terminator is not taken.
        private mutating func readPrelude() -> (String, Character)? {
            var text = ""
            var depth = 0
            var quote: Character?
            while index < chars.count {
                let c = chars[index]
                if let open = quote {
                    text.append(c)
                    if c == "\\", index + 1 < chars.count { text.append(chars[index + 1]); index += 1 }
                    else if c == open { quote = nil }
                } else if c == "\"" || c == "'" {
                    quote = c
                    text.append(c)
                } else if c == "(" || c == "[" {
                    depth += 1
                    text.append(c)
                } else if c == ")" || c == "]" {
                    depth -= 1
                    if depth < 0 { return nil }
                    text.append(c)
                } else if depth == 0, c == "{" || c == ";" || c == "}" {
                    return (text.trimmingCharacters(in: .whitespacesAndNewlines), c)
                } else {
                    text.append(c)
                }
                index += 1
            }
            return (text.trimmingCharacters(in: .whitespacesAndNewlines), "\0")
        }

        private func isSelectorOrAtRule(_ prelude: String) -> Bool {
            guard !prelude.isEmpty else { return false }
            if prelude.hasPrefix("@") { return true }
            let first = prelude.prefix { $0.isLetter || $0.isNumber || $0 == "_" }
            if scriptWords.contains(String(first)) { return false }
            // "=" belongs to an attribute selector only inside brackets, and a backtick never belongs to a selector.
            var inBrackets = 0
            for c in prelude {
                if c == "[" { inBrackets += 1 }
                else if c == "]" { inBrackets -= 1 }
                else if c == "=" && inBrackets == 0 { return false }
                else if c == "`" { return false }
            }
            return true
        }

        /// A name, a colon and a value: `color: red`, `--gap: 8px`.
        private func isDeclaration(_ text: String) -> Bool {
            guard let colon = text.firstIndex(of: ":") else { return false }
            let name = text[..<colon].trimmingCharacters(in: .whitespaces)
            let value = text[text.index(after: colon)...].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, let head = name.first, head.isLetter || head == "-" else { return false }
            return name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        }
    }
}
