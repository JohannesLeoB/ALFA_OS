import Foundation
import ALFAcolorCore

/// Sites whose links lead to code that a card could hold. Reading the code needs the network and is not done here.
public enum CodeHost: String, Equatable, Sendable {
    case gist, codepen
}

/// Code with the language and the file name of its tab.
public struct CodeSnippet: Equatable, Sendable {
    public var language: CodeLanguage
    public var fileName: String
    public var text: String
    public init(language: CodeLanguage, fileName: String, text: String) {
        self.language = language; self.fileName = fileName; self.text = text
    }
}

/// What a pasted text is.
public enum Detected: Equatable, Sendable {
    case link(URL, codeHost: CodeHost?)
    case colors([ColorEntry])
    case code(CodeSnippet)
    case note(String)
}

/// Decides what a text is. The order matters, the first match wins:
/// a single address, a list of colors, SwiftUI, React, style sheet, script, HTML, and last a note.
/// It is a pure function of the text.
public enum PasteDetector {
    /// Only the start of a long text is searched for signs. The style sheet check reads all of it.
    private static let headLength = 20_000

    public static func detect(_ text: String) -> Detected? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let link = link(in: trimmed) { return link }
        if let color = ColorList.rgb(trimmed) { return .colors([color]) }
        if let colors = ColorList.parse(trimmed) { return .colors(colors) }
        let head = String(trimmed.prefix(headLength))
        if matches(Signs.swiftUI, head) { return code(.swiftui, "View.swift", trimmed) }
        if matches(Signs.react, head) || matches(Signs.jsxTag, head) { return code(.react, "App.jsx", trimmed) }
        if matches(Signs.typeScript, head) { return code(.other, "script.ts", trimmed) }
        if CSSShape.isStyleSheet(trimmed) { return code(.css, "style.css", trimmed) }
        let hasMarkup = isMarkup(head)
        if !hasMarkup, isScript(head) { return code(.javascript, "script.js", trimmed) }
        if hasMarkup {
            return code(matches(Signs.tailwind, head) ? .tailwind : .html, "index.html", trimmed)
        }
        return .note(trimmed)
    }

    /// A single address with a scheme of http or https, and no other text.
    static func link(in text: String) -> Detected? {
        guard !text.contains(where: \.isWhitespace),
              let url = URL(string: text),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host(percentEncoded: false)?.lowercased(), !host.isEmpty else { return nil }
        return .link(url, codeHost: codeHost(of: host))
    }

    static func codeHost(of host: String) -> CodeHost? {
        func isSite(_ site: String) -> Bool { host == site || host.hasSuffix("." + site) }
        if isSite("gist.github.com") || isSite("gist.githubusercontent.com") { return .gist }
        if isSite("codepen.io") { return .codepen }
        return nil
    }

    /// True for markup that uses utility classes of Tailwind.
    static func isTailwind(_ html: String) -> Bool {
        matches(Signs.tailwind, String(html.prefix(headLength)))
    }

    private static func code(_ language: CodeLanguage, _ fileName: String, _ text: String) -> Detected {
        .code(CodeSnippet(language: language, fileName: fileName, text: text))
    }

    /// Markup: a doctype or a comment, or at least two tags that are not all inline tags. One tag in a sentence is a note.
    /// A sentence with bold text, `<b>x</b>`, has two matches of one tag, and only inline tags: a note.
    private static func isMarkup(_ text: String) -> Bool {
        if matches(Signs.doctypeOrComment, text) { return true }
        let tags = count(Signs.html, text)
        return tags >= 2 && count(Signs.inline, text) < tags
    }

    /// Script code: a function, a class, a module statement, or a use of the browser objects.
    /// A declaration alone is not enough: it needs a statement end or a block as well. An arrow needs the same.
    private static func isScript(_ text: String) -> Bool {
        if matches(Signs.script, text) { return true }
        let weak = matches(Signs.declaration, text) || matches(Signs.arrow, text)
        return weak && (text.contains(";") || text.contains("{"))
    }

    private static func matches(_ pattern: String, _ text: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }

    private static func count(_ pattern: String, _ text: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return 0 }
        return regex.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
    }

    private enum Signs {
        static let swiftUI = #"(?m)^\s*import\s+(SwiftUI|Foundation|AppKit|UIKit|SwiftData|Observation)\b|^\s*@main\b|\bstruct\s+\w+\s*:\s*(View|App|Scene)\b|\bvar\s+body\s*:\s*some\s+(View|Scene)"#

        static let react = #"(?m)\bclassName=|^\s*export\s+default\b|\bfrom\s+['"]react['"]|\buse(State|Effect|Ref|Memo|Callback)\s*\(|\breturn\s*\(\s*<"#

        /// A tag with a capital letter, as in JSX: `<Card title="x" />`.
        static let jsxTag = #"<[A-Z][A-Za-z0-9.]*(\s+[\w:@.\-]+(\s*=\s*("[^"]*"|'[^']*'|\{[^{}]*\}))?)*\s*/?>"#

        /// A typed declaration (`const a: A = …`) or an interface: TypeScript.
        static let typeScript = #"(?m)\b(const|let|var)\s+[\w$]+\s*:\s*[\w$<>\[\]|.]+\s*=|^\s*interface\s+\w+\s*\{"#

        static let doctypeOrComment = #"(?i)<!doctype\s+html|<!--"#

        static let html = #"(?i)<!doctype\s+html|<!--|</?(html|head|body|div|span|p|a|ul|ol|li|h[1-6]|img|button|input|form|section|nav|header|footer|main|article|aside|style|script|svg|table|thead|tbody|tr|td|th|label|select|option|textarea|canvas|video|audio|link|meta|title|br|hr|i|b|em|strong|pre|code|small|figure|figcaption|picture|source|iframe|dialog|details|summary)(\s+[\w:@.\-]+(\s*=\s*("[^"]*"|'[^']*'|[^\s"'<>=`]+))?)*\s*/?>"#

        /// Tags of text formatting. Several of them in a sentence are still a note.
        static let inline = #"(?i)</?(b|i|em|strong|small|code|span|a|br|u|s|mark|sub|sup|kbd|abbr)(\s+[\w:@.\-]+(\s*=\s*("[^"]*"|'[^']*'|[^\s"'<>=`]+))?)*\s*/?>"#

        static let tailwind = #"class="[^"]*\b(flex|grid|p[xy]?-\d|m[xy]?-\d|text-(xs|sm|base|lg|xl)|bg-|rounded|w-\d|h-\d)"#

        /// A plain declaration. On its own it is too weak for script code.
        static let declaration = #"(?m)\b(const|let|var)\s+[\w$]+\s*="#

        static let script = #"(?m)\bfunction\s*[\w$]*\s*\(|\bclass\s+\w+(\s+extends\s+[\w.]+)?\s*\{|\b(document|window|console)\.\w+|^\s*import\s+[^\n]*\bfrom\s+['"]|^\s*import\s+['"]|^\s*export\s+(const|let|function|class|\{)|\brequire\s*\(|\bmodule\.exports\b|\baddEventListener\s*\("#

        static let arrow = #"(\([^()]*\)|\b[\w$]+)\s*=>"#
    }
}
