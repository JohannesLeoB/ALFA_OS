import Foundation
import WebKit

/// The page of the lab: the draft as a web card, with the controls as a style that the running page takes over.
@available(macOS 26.0, *)
@MainActor
public enum LabPreview {
    /// The id of the style element that holds the control values in the page.
    static let tweakID = "lab-tweaks"

    /// Sets the style element in the running page. The argument `css` holds the new text.
    static let applyScript = "var style = document.getElementById('lab-tweaks'); if (style) { style.textContent = css; }"

    /// The document of the draft with the controls and the colour scheme. nil when the draft is not web code.
    public static func document(for draft: LabDraft, controls: [LabControl], dark: Bool) -> String? {
        guard let html = WebDocument.html(for: draft.card) else { return nil }
        let scheme = "<style>html{color-scheme:\(dark ? "dark" : "light")}</style>"
        let tweaks = "<style id=\"\(tweakID)\">\(WebDocument.escapeScript(tweakCSS(controls)))</style>"
        return insertInHead(scheme + tweaks, into: html)
    }

    /// The style of the changed controls. Each changed variable is set on the root element and on every element, marked
    /// important, so that the code's own declarations give way to it. Unchanged variables keep the code's values.
    public static func tweakCSS(_ controls: [LabControl]) -> String {
        let changed = controls.filter(\.isChanged)
        guard !changed.isEmpty else { return "" }
        let declarations = changed.map { "\($0.name):\($0.value.css) !important" }.joined(separator: ";")
        return ":root,*{\(declarations)}"
    }

    /// Takes the control values over in the running page. The page does not reload.
    public static func apply(_ controls: [LabControl], to live: LiveCard) async {
        _ = try? await live.page.callJavaScript(applyScript, arguments: ["css": tweakCSS(controls)])
    }

    /// A running page of the document, with the network rules of the cards. Its errors are kept in the live card.
    public static func makeLive(_ document: String) async throws -> LiveCard {
        var configuration = try await WebCardRenderer.configuration()
        configuration.defaultNavigationPreferences.allowsContentJavaScript = true
        let channel = CardErrorChannel()
        configuration.userContentController.add(channel, contentWorld: .page, name: WebDocument.errorChannel)
        let page = WebPage(configuration: configuration, navigationDecider: HostGuard())
        let live = LiveCard(page: page)
        channel.owner = live
        // The card origin gives the page the storage that a card has, such as localStorage.
        page.load(html: document, baseURL: WebHostRule.cardOrigin)
        return live
    }

    /// Inserts the snippet after the head tag, else after the html tag, else at the start.
    static func insertInHead(_ snippet: String, into html: String) -> String {
        for pattern in ["<head(?:\\s[^>]*)?>", "<html(?:\\s[^>]*)?>"] {
            if let range = html.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                var result = html
                result.insert(contentsOf: snippet, at: range.upperBound)
                return result
            }
        }
        return snippet + html
    }
}
