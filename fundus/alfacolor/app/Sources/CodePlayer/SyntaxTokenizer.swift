import Foundation

/// The kinds of text the highlighter tells apart. Plain text has no color of its own.
public enum SyntaxKind: Equatable, Sendable {
    case plain, comment, string, keyword, type, number, tag, attribute
}

/// A piece of source code and its kind. The pieces joined in order give the source back exactly.
public struct SyntaxToken: Equatable, Sendable {
    public let kind: SyntaxKind
    public let text: String

    public init(kind: SyntaxKind, text: String) {
        self.kind = kind
        self.text = text
    }
}

/// Splits source code into colored pieces, with one pattern per family and no outside library.
/// The rules follow the highlighter of the browser prototype: the first group that matches decides the kind.
public enum SyntaxTokenizer {
    /// The pieces of `code`, in order. Neighbouring pieces of one kind are joined.
    public static func tokens(_ code: String, family: SyntaxFamily) -> [SyntaxToken] {
        let rule = Rule.of(family)
        let text = code as NSString
        var raw: [SyntaxToken] = []
        var last = 0
        for match in rule.regex.matches(in: code, range: NSRange(location: 0, length: text.length)) where match.range.length > 0 {
            if match.range.location > last {
                raw.append(SyntaxToken(kind: .plain, text: text.substring(with: NSRange(location: last, length: match.range.location - last))))
            }
            var kind = SyntaxKind.plain
            for group in 1..<match.numberOfRanges where match.range(at: group).location != NSNotFound {
                kind = rule.kind(group, text.substring(with: match.range(at: group)))
                break
            }
            raw.append(SyntaxToken(kind: kind, text: text.substring(with: match.range)))
            last = match.range.location + match.range.length
        }
        if last < text.length {
            raw.append(SyntaxToken(kind: .plain, text: text.substring(from: last)))
        }
        return joined(raw)
    }

    /// Joins neighbours of one kind. One pass, so that long runs of plain text stay cheap.
    private static func joined(_ pieces: [SyntaxToken]) -> [SyntaxToken] {
        var result: [SyntaxToken] = []
        var kind: SyntaxKind?
        var text = ""
        for piece in pieces {
            if piece.kind != kind, let current = kind {
                result.append(SyntaxToken(kind: current, text: text))
                text = ""
            }
            kind = piece.kind
            text += piece.text
        }
        if let current = kind {
            result.append(SyntaxToken(kind: current, text: text))
        }
        return result
    }

    /// The pattern and the kind of each group of one family. Group 1 is the first group of the pattern.
    private struct Rule {
        let regex: NSRegularExpression
        let kind: (Int, String) -> SyntaxKind

        static func of(_ family: SyntaxFamily) -> Rule {
            switch family {
            case .swift:
                Rule(regex: pattern(swiftPattern)) { group, text in
                    switch group {
                    case 1: .comment
                    case 2: .string
                    case 3: identifier(text, keywords: swiftKeywords)
                    default: .number
                    }
                }
            case .script:
                Rule(regex: pattern(scriptPattern)) { group, text in
                    switch group {
                    case 1: .comment
                    case 2: .string
                    case 3: .tag
                    case 4: identifier(text, keywords: scriptKeywords)
                    default: .number
                    }
                }
            case .markup:
                Rule(regex: pattern(markupPattern)) { group, _ in
                    switch group {
                    case 1: .comment
                    case 2: .string
                    case 3: .tag
                    case 4: .attribute
                    default: .number
                    }
                }
            }
        }

        /// A keyword is a keyword; a name that starts with a capital is a type; other names are plain.
        private static func identifier(_ text: String, keywords: Set<String>) -> SyntaxKind {
            if keywords.contains(text) { return .keyword }
            return text.first?.isUppercase == true ? .type : .plain
        }

        // The patterns are constants, so a failure to compile is a programming error.
        private static func pattern(_ source: String) -> NSRegularExpression {
            guard let regex = try? NSRegularExpression(pattern: source) else {
                preconditionFailure("Invalid syntax pattern")
            }
            return regex
        }
    }

    private static let swiftPattern = #"(//[^\n]*|/\*[\s\S]*?\*/)|("""[\s\S]*?"""|"(?:[^"\\\n]|\\.)*")|(@?[A-Za-z_]\w*)|(\b\d[\d_.]*\b)"#

    private static let scriptPattern = #"(//[^\n]*|/\*[\s\S]*?\*/)|("(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*'|`(?:[^`\\]|\\.)*`)|(</?[A-Za-z][\w.:-]*)|(@?[A-Za-z_$][\w$]*)|(\b\d[\d_.]*\b)"#

    private static let markupPattern = #"(<!--[\s\S]*?-->|/\*[\s\S]*?\*/)|("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*')|(</?[A-Za-z][\w:-]*)|([A-Za-z_:@][\w:.@-]*)(?==)|(\b\d[\d.]*\b)"#

    private static let swiftKeywords: Set<String> = [
        "import", "struct", "class", "enum", "protocol", "extension", "func", "var", "let", "if", "else", "guard",
        "switch", "case", "default", "for", "in", "while", "repeat", "return", "some", "any", "self", "Self", "super",
        "init", "deinit", "static", "private", "fileprivate", "public", "internal", "open", "final", "override",
        "mutating", "nonmutating", "throws", "rethrows", "throw", "try", "catch", "do", "await", "async", "actor",
        "where", "as", "is", "nil", "true", "false", "typealias", "associatedtype", "subscript", "lazy", "weak",
        "unowned", "inout", "break", "continue", "defer", "get", "set", "willSet", "didSet", "convenience",
        "required", "indirect",
    ]

    private static let scriptKeywords: Set<String> = [
        "const", "let", "var", "function", "return", "if", "else", "for", "while", "do", "switch", "case", "default",
        "break", "continue", "new", "this", "class", "extends", "import", "export", "from", "async", "await", "try",
        "catch", "finally", "throw", "typeof", "instanceof", "in", "of", "null", "undefined", "true", "false", "void",
        "delete", "yield", "static", "get", "set",
    ]
}
