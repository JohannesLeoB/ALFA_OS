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
    <script>addEventListener("error",function(e){var m=String(e.message||e.error);try{window.webkit.messageHandlers.\#(errorChannel).postMessage(m)}catch(x){}var d=document.createElement("pre");d.style.cssText="margin:0;padding:8px;font:12px/1.4 monospace;white-space:pre-wrap;color:inherit;border-bottom:1px solid currentColor";d.textContent=m;(document.body||document.documentElement).appendChild(d)})</script>
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
        var code = stripModules(source.joined(separator: "\n"))
        var name: String?
        if let match = code.firstMatch(of: /export\s+default\s+function\s+([A-Z][A-Za-z0-9_]*)/) {
            name = String(match.output.1)
        }
        code = code.replacing(/export\s+default\s+function/, with: "function")
        code = code.replacing(/^[ \t]*export[ \t]*\{[^}]*\}[ \t]*;?[ \t]*$/.anchorsMatchLineEndings(), with: "")
        code = code.replacing(/export\s+(const|function|class|let|var|type|interface|enum)/) { String($0.output.1) }
        if name == nil, let match = code.firstMatch(of: /export\s+default\s+([A-Z][A-Za-z0-9_]*)/) {
            name = String(match.output.1)
        }
        code = code.replacing(/export\s+default\s+[A-Z][A-Za-z0-9_]*\s*;?/, with: "")
        if name == nil, let match = code.firstMatch(of: /(?:function|const)\s+([A-Z][A-Za-z0-9_]*)/) {
            name = String(match.output.1)
        }
        let render = name.map { "ReactDOM.createRoot(document.getElementById('root')).render(React.createElement(\($0)));" }
            ?? "document.body.textContent='No component found: add export default or a capitalised function.';"
        let styles = named(files, ".css").map { "<style>\(escapeScript($0))</style>" }.joined()
        let scripts = reactScripts.map { #"<script src="\#($0)"></script>"# }.joined()
        let body = "const {useState,useEffect,useRef,useMemo,useCallback,Fragment}=React;\n" + escapeScript(code) + "\n" + render
        let mount: String
        if files.keys.contains(where: { $0.lowercased().hasSuffix(".ts") || $0.lowercased().hasSuffix(".tsx") }) {
            mount = #"<div id="root"></div><script type="text/plain" id="card">"# + body + "</script>" + typedRunner
        } else {
            mount = #"<div id="root"></div><script type="text/babel" data-presets="react">"# + body + "</script>"
        }
        return "<!doctype html><html><head>" + basis + errorScript + #"<script src="\#(tailwindScript)"></script>"# + scripts + styles
            + "</head><body>" + mount + "</body></html>"
    }

    /// Compiles a TypeScript card with Babel's own call and runs the result. The page's `text/babel` path
    /// fails on `as const` in this setup, so the call is explicit. Its errors reach the card and the
    /// error channel with their message.
    static let typedRunner = #"""
    <script>(function () {
      var root = document.getElementById('root');
      try {
        var out = Babel.transform(document.getElementById('card').textContent,
          { presets: ['typescript', 'react'], filename: 'card.tsx' }).code;
        (0, eval)(out);
      } catch (e) {
        var text = String((e && e.message) || e);
        root.textContent = text;
        try { window.webkit.messageHandlers.\#(errorChannel).postMessage(text); } catch (x) {}
      }
    })();
    </script>
    """#

    /// Removes import lines and "use client" markers. The page has React as a global.
    static func stripModules(_ code: String) -> String {
        code.replacing(/^\s*import[^\n]*\n/.anchorsMatchLineEndings(), with: "")
            .replacing(/^\s*["']use client["'];?\s*$/.anchorsMatchLineEndings(), with: "")
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
