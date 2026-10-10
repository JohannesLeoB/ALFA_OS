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

/// A language that does not run in the page. Code in it needs a translation before a card can play it.
public enum ForeignLanguage: String, Equatable, Sendable, CaseIterable {
    case swift, kotlin, java, dart, python

    /// The language that a card of this code gets.
    public var codeLanguage: CodeLanguage {
        switch self {
        case .swift: .swiftui
        case .kotlin: .compose
        case .java: .java
        case .dart: .flutter
        case .python: .other
        }
    }

    public var fileName: String {
        switch self {
        case .swift: "View.swift"
        case .kotlin: "Screen.kt"
        case .java: "Main.java"
        case .dart: "main.dart"
        case .python: "script.py"
        }
    }
}

/// What the code of a text is. Only the kinds that run in a card are playable.
public enum CodeKind: Equatable, Sendable {
    case html, css, tailwind, react, script, svg, json
    /// Code in a language that the page does not run. It needs a translation first.
    case foreign(ForeignLanguage)
    case notCode

    public var isPlayable: Bool {
        switch self {
        case .html, .css, .tailwind, .react, .script, .svg: true
        case .json, .foreign, .notCode: false
        }
    }
}

/// What makes a classification unsure. Each one can become a question later; no more than `maxDoubts` are kept.
public enum Doubt: String, Equatable, Sendable {
    /// Only a weak sign decided the kind.
    case fewSigns
    /// Markup with loose style rules or script statements next to it, outside any tag that holds them.
    case mixedKinds
}

public enum Certainty: Equatable, Sendable {
    case sure, unsure
}

/// The kind of a pasted code with how sure the reading is, and what is unsure.
public struct CodeClassification: Equatable, Sendable {
    public static let maxDoubts = 3

    public var kind: CodeKind
    /// TypeScript syntax in a script or a React component.
    public var typed = false
    /// Utility classes of Tailwind in markup, in a React component, or directives in a style sheet.
    public var usesTailwind = false
    /// The kinds that markup carries in its own tags: a style sheet, a script.
    public var embedded: [CodeKind] = []
    public var doubts: [Doubt] = []

    public init(kind: CodeKind) { self.kind = kind }

    public var certainty: Certainty { doubts.isEmpty ? .sure : .unsure }
    public var isPlayable: Bool { kind.isPlayable }
    public var needsTranslation: Bool {
        if case .foreign = kind { return true }
        return false
    }
}

/// Decides what a text is. The order matters, the first match wins:
/// a single address, a list of colors, SwiftUI and the other foreign languages, React, style sheet, script, HTML, and last a note.
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
        let report = classifyCode(trimmed)
        switch report.kind {
        case .foreign(let language): return code(language.codeLanguage, language.fileName, trimmed)
        case .react: return code(.react, report.typed ? "App.tsx" : "App.jsx", trimmed)
        case .script: return report.typed ? code(.other, "script.ts", trimmed) : code(.javascript, "script.js", trimmed)
        case .css: return code(.css, "style.css", trimmed)
        case .tailwind: return code(.tailwind, "index.html", trimmed)
        case .html: return code(.html, "index.html", trimmed)
        case .svg: return code(report.usesTailwind ? .tailwind : .html, "index.html", trimmed)
        case .json, .notCode: return .note(trimmed)
        }
    }

    /// The kind of the code in a text, how sure it is, and what is unsure. It is a pure function of the text.
    public static func classify(_ text: String) -> CodeClassification {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, link(in: trimmed) == nil, ColorList.rgb(trimmed) == nil, ColorList.parse(trimmed) == nil else {
            return CodeClassification(kind: .notCode)
        }
        return classifyCode(trimmed)
    }

    /// The classification of a text that is neither empty, nor an address, nor a list of colors.
    private static func classifyCode(_ trimmed: String) -> CodeClassification {
        let head = String(trimmed.prefix(headLength))
        if matches(Signs.swiftUI, head) { return CodeClassification(kind: .foreign(.swift)) }
        if let language = foreignLanguage(head) { return CodeClassification(kind: .foreign(language)) }
        if isSVG(trimmed) {
            var result = CodeClassification(kind: .svg)
            result.usesTailwind = matches(Signs.tailwind, head)
            return result
        }
        if isJSON(trimmed) { return CodeClassification(kind: .json) }
        if matches(Signs.react, head) || matches(Signs.jsxTag, head) {
            var result = CodeClassification(kind: .react)
            result.typed = isTypeScript(head)
            result.usesTailwind = matches(Signs.tailwindClassName, head)
            if !matches(Signs.reactStrong, head) && !matches(Signs.jsxTag, head) { result.doubts = [.fewSigns] }
            return result
        }
        if matches(Signs.typeScript, head) {
            var result = CodeClassification(kind: .script)
            result.typed = true
            return result
        }
        if CSSShape.isStyleSheet(trimmed) {
            var result = CodeClassification(kind: .css)
            result.usesTailwind = matches(Signs.tailwindDirective, head)
            return result
        }
        let hasMarkup = isMarkup(head)
        if !hasMarkup, isScript(head) {
            var result = CodeClassification(kind: .script)
            if !matches(Signs.script, head) { result.doubts = [.fewSigns] }
            return result
        }
        if hasMarkup {
            let tailwind = matches(Signs.tailwind, head)
            var result = CodeClassification(kind: tailwind ? .tailwind : .html)
            result.usesTailwind = tailwind
            if matches(Signs.styleTag, head) { result.embedded.append(.css) }
            if matches(Signs.scriptTag, head) { result.embedded.append(.script) }
            if hasLooseCode(head) { result.doubts.append(.mixedKinds) }
            return result
        }
        return CodeClassification(kind: .notCode)
    }

    /// True when the text outside of tags, style elements and script elements holds a style rule or script code.
    private static func hasLooseCode(_ markup: String) -> Bool {
        var loose = markup.replacingOccurrences(of: Signs.holder, with: "", options: .regularExpression)
        loose = loose.replacingOccurrences(of: Signs.anyTag, with: "", options: .regularExpression)
        return matches(Signs.looseRule, loose) || matches(Signs.script, loose)
    }

    /// Markup whose root is an svg element, with an optional xml line, comments and doctype in front.
    static func isSVG(_ text: String) -> Bool {
        text.lowercased().hasSuffix("</svg>") && matches(Signs.svgStart, String(text.prefix(headLength)))
    }

    /// A JSON object or array that is not empty.
    static func isJSON(_ text: String) -> Bool {
        guard let first = text.first, first == "{" || first == "[",
              let value = try? JSONSerialization.jsonObject(with: Data(text.utf8)) else { return false }
        if let object = value as? [String: Any] { return !object.isEmpty }
        if let array = value as? [Any] { return !array.isEmpty }
        return false
    }

    /// The foreign language of a text, other than Swift, when it shows a sign of it that no script has.
    /// Dart goes first, because its imports look like script imports and its classes like Java's.
    static func foreignLanguage(_ text: String) -> ForeignLanguage? {
        if matches(Signs.dart, text) { return .dart }
        if matches(Signs.kotlin, text) { return .kotlin }
        if matches(Signs.java, text) { return .java }
        if matches(Signs.python, text) { return .python }
        return nil
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

    /// TypeScript: a type or interface declaration, a typed parameter, or a typed constant.
    private static func isTypeScript(_ text: String) -> Bool {
        matches(Signs.typeDeclaration, text) || matches(Signs.typedParameter, text) || matches(Signs.typeScript, text)
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

        static let dart = #"(?m)^\s*import\s+['"](package|dart):|^\s*void\s+main\s*\(|\bextends\s+(StatelessWidget|StatefulWidget|State<)|\bWidget\s+build\s*\(\s*BuildContext"#

        static let kotlin = #"(?m)@Composable\b|^\s*package\s+[\w.]+\s*$|^\s*import\s+(androidx|kotlinx?|android)\.[\w.*]+\s*$|^\s*((private|public|internal|override|suspend|inline|open)\s+)*fun\s+(<[^>]*>\s*)?[\w.]+\s*\(|^\s*(data|sealed|enum|open)\s+class\s+\w+|^\s*object\s+\w+\s*(:|\{)|\bcompanion\s+object\b"#

        static let java = #"(?m)^\s*package\s+[\w.]+;|^\s*import\s+(static\s+)?(java|javax|android|androidx|org|com)\.[\w.*]+;|\bSystem\.(out|err)\.print|^\s*(public|private|protected)\s+(static\s+)?(final\s+)?(abstract\s+)?(class|interface|enum|record)\s+\w+|\bpublic\s+static\s+void\s+main\b|^\s*@Override\b"#

        static let python = #"(?m)^\s*def\s+\w+\s*\([^)]*\)\s*(->\s*[^:\n]+)?:\s*(#.*)?$|^\s*class\s+\w+(\([^)]*\))?:\s*$|^\s*from\s+[\w.]+\s+import\s+[\w*(]|^\s*if\s+__name__\s*==|^\s*import\s+[\w.]+(\s+as\s+\w+)?(\s*,\s*[\w.]+(\s+as\s+\w+)?)*\s*$"#

        /// Signs that only React code has. `export default` alone is not one of them.
        static let reactStrong = #"\bclassName=|\bfrom\s+['"]react['"]|\buse(State|Effect|Ref|Memo|Callback)\s*\(|\breturn\s*\(?\s*<[A-Za-z>]"#

        /// Utility classes in a `className`, also inside a call such as `cn("flex p-4")`.
        static let tailwindClassName = #"class(Name)?\s*=\s*\{?\s*(\w+\()?\s*["'`][^"'`]*\b(flex|grid|[pm][xytblr]?-\d|text-(xs|sm|base|lg|\d?xl)|bg-|rounded|[wh]-\d|items-|justify-|gap-\d|space-[xy]-|font-(medium|semibold|bold)|absolute|relative)"#

        /// The directives of Tailwind in a style sheet.
        static let tailwindDirective = #"(?m)^\s*@(import\s+["']tailwindcss|tailwind\s|theme\b|apply\b|utility\b|custom-variant\b|source\b)"#

        /// A style or script element with its content, and a comment.
        static let holder = #"(?is)<(style|script)\b.*?</\1\s*>|<!--.*?-->"#
        static let anyTag = #"(?s)<[^>]*>"#
        /// A style rule on its own: a selector, then a block with at least one declaration.
        static let looseRule = #"(?m)^\s*[.#\w][^{}\n]*\{[^{}]*:[^{}]*\}"#

        static let styleTag = #"(?i)<style\b"#
        static let scriptTag = #"(?i)<script\b"#
        static let svgStart = #"(?is)^\s*(<\?xml[^>]*\?>\s*)?(<!--.*?-->\s*)*(<!doctype\s+svg[^>]*>\s*)?<svg\b"#

        static let react = #"(?m)\bclassName=|^\s*export\s+default\b|\bfrom\s+['"]react['"]|\buse(State|Effect|Ref|Memo|Callback)\s*\(|\breturn\s*\(\s*<"#

        /// A tag with a capital letter, as in JSX: `<Card title="x" />`.
        static let jsxTag = #"<[A-Z][A-Za-z0-9.]*(\s+[\w:@.\-]+(\s*=\s*("[^"]*"|'[^']*'|\{[^{}]*\}))?)*\s*/?>"#

        /// A typed declaration (`const a: A = …`) or an interface: TypeScript.
        static let typeScript = #"(?m)\b(const|let|var)\s+[\w$]+\s*:\s*[\w$<>\[\]|.]+\s*=|^\s*interface\s+\w+\s*\{"#

        /// A type or an interface declared at the start of a line.
        static let typeDeclaration = #"(?m)^\s*(export\s+)?(type|interface)\s+[A-Za-z_]\w*\s*(=|\{|<)"#

        /// A parameter with a type name, as in `({ heat = 60 }: Props)` or `(props: Props)`.
        static let typedParameter = #"\(\s*(\{[^{}]*\}|\w+)\s*:\s*[A-Z][A-Za-z0-9_.<>\[\]]*\s*\)"#

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
