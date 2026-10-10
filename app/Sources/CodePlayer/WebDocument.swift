import ALFAcolorCore
import Foundation

/// Builds the HTML document of a web card: markup, styles, scripts and the error channel in one page.
public enum WebDocument {
    /// Name of the script message handler: `window.webkit.messageHandlers.cardError.postMessage(text)`.
    public static let errorChannel = "cardError"

    static let tailwindScript = "https://cdn.tailwindcss.com"
    static let reactScripts = [
        "https://cdnjs.cloudflare.com/ajax/libs/react/18.3.1/umd/react.production.min.js",
        "https://cdnjs.cloudflare.com/ajax/libs/react-dom/18.3.1/umd/react-dom.production.min.js",
        "https://cdnjs.cloudflare.com/ajax/libs/babel-standalone/7.26.4/babel.min.js",
    ]

    static let basis = #"<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><style>html,body{margin:0}body{font-family:system-ui,-apple-system,sans-serif}</style>"#

    /// Shows an uncaught error in the card and posts it to the error channel.
    static let errorScript = #"""
    <script>addEventListener("error",function(e){var m=String(e.message||e.error);if(e.lineno){m+=" ("+e.lineno+":"+e.colno+")"}try{window.webkit.messageHandlers.\#(errorChannel).postMessage(m)}catch(x){}var d=document.createElement("pre");d.style.cssText="margin:0;padding:8px;font:12px/1.4 monospace;white-space:pre-wrap;color:inherit;border-bottom:1px solid currentColor";d.textContent=m;(document.body||document.documentElement).appendChild(d)})</script>
    """#

    /// The HTML of a card, or nil when the language is not a web language.
    public static func html(for card: CodeCard) -> String? {
        let files = card.files
        switch card.language {
        case .html:
            return compose(markup: markupFile(files) ?? "", styles: named(files, ".css"), scripts: named(files, ".js"), tailwind: false)
        case .css:
            return compose(markup: "", styles: named(files, ".css"), scripts: [], tailwind: false)
        case .javascript:
            return compose(markup: "", styles: [], scripts: files.keys.sorted().compactMap { files[$0] }, tailwind: false)
        case .tailwind:
            let markup = markupFile(files) ?? otherFile(files) ?? ""
            return compose(markup: markup, styles: named(files, ".css"), scripts: named(files, ".js"), tailwind: true)
        case .react:
            return react(files)
        case .swiftui, .compose, .flutter, .java, .other:
            return nil
        }
    }

    /// The page for markup, styles and scripts. A full document gets the parts in its head and at its end.
    static func compose(markup: String, styles: [String], scripts: [String], tailwind: Bool) -> String {
        let tailwindTag = tailwind ? #"<script src="\#(tailwindScript)"></script>"# : ""
        let styleTags = styles.map { "<style>\(escapeScript($0))</style>" }.joined()
        let scriptTags = scripts.map { "<script>\(escapeScript($0))</script>" }.joined()
        let extras = errorScript + tailwindTag + styleTags
        if markup.range(of: "<html", options: .caseInsensitive) != nil {
            var document = markup
            if let head = document.range(of: "<head[^>]*>", options: [.regularExpression, .caseInsensitive]) {
                document.insert(contentsOf: extras, at: head.upperBound)
            } else {
                document = extras + document
            }
            return document + scriptTags
        }
        return "<!doctype html><html><head>" + basis + extras + "</head><body>" + markup + scriptTags + "</body></html>"
    }

    /// A React card: the component is compiled by Babel in the page. Imports and module markers are dropped.
    /// A card with a `.ts` or `.tsx` file is compiled with the TypeScript and React presets as `card.tsx`
    /// (see `typedRunner`). Babel needs a file name to run the TypeScript preset.
    static func react(_ files: [String: String]) -> String {
        let source = files.keys.sorted().filter { !$0.lowercased().hasSuffix(".css") }.compactMap { files[$0] }
        let joined = source.joined(separator: "\n")
        let name = componentName(in: stripModules(joined))
        var code = stripModules(joined)
        code = dropDefaultExport(code)
        code = code.replacing(/^[ \t]*export[ \t]*\{[^}]*\}[ \t]*;?[ \t]*$/.anchorsMatchLineEndings(), with: "")
        code = code.replacing(/export\s+(const|function|class|let|var|type|interface|enum)/) { String($0.output.1) }
        let render = name.map { mountCode($0) }
            ?? "document.body.textContent='No component found: add export default or a capitalised function.';"
        let styles = named(files, ".css").map { "<style>\(escapeScript($0))</style>" }.joined()
        let scripts = reactScripts.map { #"<script src="\#($0)"></script>"# }.joined()
        // No line break after the destructuring, so that the source lines keep their numbers for error positions.
        let provided = reactNames.filter { !declares($0, in: code) }.joined(separator: ",")
        let body = (provided.isEmpty ? "" : "const {\(provided)}=React;") + escapeScript(code) + "\n" + render
        let mount: String
        if files.keys.contains(where: { $0.lowercased().hasSuffix(".ts") || $0.lowercased().hasSuffix(".tsx") }) {
            mount = #"<div id="root"></div><script type="text/plain" id="card">"# + body + "</script>" + typedRunner
        } else {
            mount = #"<div id="root"></div><script type="text/babel" data-presets="react">"# + body + "</script>"
        }
        return "<!doctype html><html><head>" + basis + errorScript + #"<script src="\#(tailwindScript)"></script>"# + scripts + styles
            + "</head><body>" + mount + "</body></html>"
    }

    /// The names of React that a card may use without an import. The page gives the ones that the code does not declare.
    static let reactNames = [
        "useState", "useEffect", "useRef", "useMemo", "useCallback", "useReducer", "useContext", "useLayoutEffect",
        "useId", "useTransition", "useDeferredValue", "useImperativeHandle", "useSyncExternalStore",
        "forwardRef", "memo", "createContext", "createElement", "cloneElement", "Children", "Fragment", "Suspense", "lazy",
    ]

    /// True when the code declares the name itself: a variable, function or class, or a destructuring.
    static func declares(_ name: String, in code: String) -> Bool {
        let pattern = "\\b(?:(?:const|let|var|function|class)\\s+\(name)\\b|(?:const|let|var)\\s*\\{[^}]*\\b\(name)\\b[^}]*\\})"
        return code.range(of: pattern, options: .regularExpression) != nil
    }

    /// The name that an anonymous default export gets, so that the page can draw it.
    static let defaultName = "CardDefault"

    /// The component that the page draws. In order: the default export, a named export whose body is JSX, and the
    /// last function, class or constant whose body is JSX. A constant in capitals (`SHAPES`, `W`) is never the component.
    static func componentName(in source: String) -> String? {
        if let name = defaultExportName(in: source) {
            return name
        }
        let found = declarations(in: source)
        if let named = found.first(where: { $0.exported && $0.isComponent }) {
            return named.name
        }
        return found.last(where: { $0.isComponent })?.name
    }

    /// The name of the default export: the name of its function or class, the name that it points to, or
    /// `defaultName` when it is anonymous or an expression such as `memo(...)`. nil without a default export.
    static func defaultExportName(in source: String) -> String? {
        guard let marker = source.firstMatch(of: /export\s+default\s+/) else { return nil }
        let rest = source[marker.range.upperBound...]
        if let match = rest.prefixMatch(of: /(?:async\s+)?function\b\s*\*?\s*([A-Za-z_$][A-Za-z0-9_$]*)/) {
            return String(match.output.1)
        }
        if let match = rest.prefixMatch(of: /class\s+(?!extends\b)([A-Za-z_$][A-Za-z0-9_$]*)/) {
            return String(match.output.1)
        }
        if let match = rest.prefixMatch(of: /(?m)([A-Za-z_$][A-Za-z0-9_$]*)(?=[ \t]*;?[ \t]*$)/) {
            return String(match.output.1)
        }
        return defaultName
    }

    /// The code without its default export marker. A named function or class and a name that is only exported keep
    /// their name. An anonymous function or class gets `defaultName`. Any other expression is assigned to it.
    static func dropDefaultExport(_ code: String) -> String {
        guard let marker = code.firstMatch(of: /export\s+default\s+/) else { return code }
        let head = code[..<marker.range.lowerBound]
        let rest = code[marker.range.upperBound...]
        if let match = rest.prefixMatch(of: /((?:async\s+)?function\b)(\s*\*?\s*)([A-Za-z_$][A-Za-z0-9_$]*)?/) {
            if match.output.3 != nil { return String(head + rest) }
            return String(head) + match.output.1 + " " + defaultName + rest[match.range.upperBound...]
        }
        if rest.prefixMatch(of: /class\s+(?!extends\b)[A-Za-z_$][A-Za-z0-9_$]*/) != nil { return String(head + rest) }
        if let match = rest.prefixMatch(of: /class\b/) {
            return String(head) + "class " + defaultName + rest[match.range.upperBound...]
        }
        if let match = rest.prefixMatch(of: /(?m)[A-Za-z_$][A-Za-z0-9_$]*[ \t]*;?(?=[ \t]*$)/) {
            return String(head + rest[match.range.upperBound...])
        }
        return String(head) + "const " + defaultName + " = " + rest
    }

    /// A top-level function or constant with its body: the text up to the next top-level declaration.
    struct Declaration {
        let name: String
        let exported: Bool
        let isConstant: Bool
        let body: String

        /// True for a capitalised function or class, or a constant that is not in capitals, whose body returns JSX.
        var isComponent: Bool {
            guard let first = name.first, first.isUppercase else { return false }
            if isConstant && !name.contains(where: \.isLowercase) { return false }
            return body.contains(/(?:return|=>)[^;{}]*?<[A-Za-z>]|createElement\s*\(/)
        }
    }

    /// The top-level functions and constants of the source, in source order.
    static func declarations(in source: String) -> [Declaration] {
        let starts = source.matches(of: /(?m)^(export[ \t]+)?(const|function|class)[ \t]+([A-Za-z_][A-Za-z0-9_]*)/)
        return starts.enumerated().map { index, match in
            let end = index + 1 < starts.count ? starts[index + 1].range.lowerBound : source.endIndex
            return Declaration(name: String(match.output.3), exported: match.output.1 != nil,
                               isConstant: match.output.2 == "const", body: String(source[match.range.upperBound..<end]))
        }
    }

    /// Draws the component in a root that keeps its props: `window.__setProps(object)` draws it again with new props
    /// and no reload. The first drawing takes `window.__initialProps`, which a lab page may set before the card runs.
    static func mountCode(_ component: String) -> String {
        "window.__root=ReactDOM.createRoot(document.getElementById('root'));"
            + "window.__setProps=function(p){window.__root.render(React.createElement(\(component),p||{}))};"
            + "window.__setProps(window.__initialProps||{});"
    }

    /// Compiles a TypeScript card with Babel's own call and runs the result. The page's `text/babel` path
    /// fails on `as const` in this setup, so the call is explicit. Its errors reach the card and the
    /// error channel with their message.
    static let typedRunner = #"""
    <script>(function () {
      var root = document.getElementById('root');
      var out;
      try {
        out = Babel.transform(document.getElementById('card').textContent,
          { presets: ['typescript', 'react'], filename: 'card.tsx', retainLines: true }).code;
      } catch (e) {
        var text = String((e && e.message) || e);
        root.textContent = text;
        try { window.webkit.messageHandlers.\#(errorChannel).postMessage(text); } catch (x) {}
        return;
      }
      // A script element with a source name: an error while it runs reports card.tsx with its line and column.
      var s = document.createElement('script');
      s.textContent = out + '\n//# sourceURL=card.tsx';
      document.body.appendChild(s);
    })();
    </script>
    """#

    /// Removes import statements, also over several lines, and "use client" markers. The page has React as a global.
    /// Each removed line leaves an empty line, so the lines of the rest keep their numbers.
    static func stripModules(_ code: String) -> String {
        // An import statement: the word `import`, a clause without quotes or semicolons, and the quoted source.
        // `import(` and `import.meta` are no statements, and a name such as `importantCall` is no keyword.
        let withoutImports = code.replacing(/(?m)^[ \t]*import\b(?![ \t]*[.(])[^"';]*?["'][^"'\n]*["'][ \t]*;?/) {
            String(repeating: "\n", count: $0.output.filter { $0 == "\n" }.count)
        }
        return withoutImports.replacing(/^\s*["']use client["'];?\s*$/.anchorsMatchLineEndings(), with: "")
    }

    /// A script that tells whether a React page has drawn: React is loaded and the root has content, or the page shows an error.
    static let drawnCheck = #"var r=document.getElementById('root');return !!(window.React&&window.ReactDOM&&((r&&r.childNodes.length)||document.querySelector('pre')));"#

    /// Keeps user code from closing the script or style element it sits in.
    static func escapeScript(_ code: String) -> String {
        code.replacing(/<\/(script|style)/.ignoresCase()) { "<\\/" + $0.output.1 }
    }

    /// The files with the given extension, in name order.
    static func named(_ files: [String: String], _ ext: String) -> [String] {
        files.keys.filter { $0.lowercased().hasSuffix(ext) }.sorted().compactMap { files[$0] }
    }

    /// index.html if present, else the first HTML file by name.
    static func markupFile(_ files: [String: String]) -> String? {
        if let index = files["index.html"] { return index }
        return named(files, ".html").first
    }

    /// The first file by name that is neither a style nor a script.
    static func otherFile(_ files: [String: String]) -> String? {
        files.keys.sorted().first { !$0.lowercased().hasSuffix(".css") && !$0.lowercased().hasSuffix(".js") }
            .flatMap { files[$0] }
    }
}
