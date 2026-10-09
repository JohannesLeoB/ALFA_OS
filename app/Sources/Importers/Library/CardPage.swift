import Foundation

/// The HTML page of one starter card. It loads Tailwind, React, Babel and motion at fixed versions, runs the
/// sources in order and then draws the component. Each script address is on the allow list of WebHostRule.
public enum CardPage {
    /// Script addresses in load order. React and motion are globals, so they come before the sources.
    public static let scripts = [
        "https://cdn.tailwindcss.com",
        "https://cdnjs.cloudflare.com/ajax/libs/react/18.3.1/umd/react.production.min.js",
        "https://cdnjs.cloudflare.com/ajax/libs/react-dom/18.3.1/umd/react-dom.production.min.js",
        "https://cdnjs.cloudflare.com/ajax/libs/babel-standalone/7.26.4/babel.min.js",
        "https://cdn.jsdelivr.net/npm/framer-motion@11.12.0/dist/framer-motion.js",
    ]

    /// Name of the message handler that receives errors from the page. The renderer installs it.
    static let errorChannel = "cardError"

    /// The page. `sources` are the texts of the files in run order; `render` names the component that is drawn.
    /// The code is compiled by Babel in the page, with its file name set to card.tsx so that JSX parses.
    /// A compile or run error is written into the card and posted to the error channel.
    public static func html(sources: [String], render: String) -> String {
        let draw = "ReactDOM.createRoot(document.getElementById('root')).render(React.createElement(\(render)));"
        let code = (sources.map(CardSource.script) + [draw]).joined(separator: "\n")
        let tags = scripts.map { #"<script src="\#($0)"></script>"# }.joined(separator: "\n")
        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <style>html,body{margin:0}body{font-family:system-ui,-apple-system,sans-serif}</style>
        \(tags)
        </head>
        <body>
        <div id="root"></div>
        <script type="text/plain" id="card">
        \(escapeScript(code))
        </script>
        <script>
        (function () {
          var root = document.getElementById('root');
          try {
            var out = Babel.transform(document.getElementById('card').textContent,
              { presets: ['typescript', 'react'], filename: 'card.tsx' }).code;
            (0, eval)(out);
          } catch (e) {
            var text = String((e && e.message) || e);
            root.textContent = text;
            try { window.webkit.messageHandlers.\(errorChannel).postMessage(text); } catch (x) {}
          }
        })();
        </script>
        </body>
        </html>

        """
    }

    /// Keeps the code from closing its script element.
    static func escapeScript(_ code: String) -> String {
        code.replacing(/<\/(script)/.ignoresCase()) { "<\\/" + $0.output.1 }
    }
}
