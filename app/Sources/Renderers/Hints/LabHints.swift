import Foundation

/// The rules of the lab hints. A hint says what a draft lacks; a fix adds the missing line to its markup.
public enum LabHints {
    /// The hints of a draft, in a fixed order: styles without markup, blocked hosts, libraries, then components.
    public static func hints(for draft: LabDraft) -> [LabHint] {
        var found: [LabHint] = []
        if isStyleOnly(draft) {
            found.append(LabHint(kind: .styleOnly))
        }
        for host in blockedHosts(in: [draft.html, draft.css, draft.script]) {
            found.append(LabHint(kind: .blockedHost(host)))
        }
        for library in LabLibrary.all where usesLibrary(library, in: draft) && !hasScriptTag(library, in: draft.html) {
            // A React draft has no markup tab, so its library has no fix.
            found.append(LabHint(kind: .library(library.name), fix: draft.art == .react ? nil : library.tag))
        }
        if hasNoComponent(draft) {
            found.append(LabHint(kind: .noComponent))
        }
        return found
    }

    /// Styles and no markup, no script. A React draft has no markup tab, so it never counts as styles only.
    static func isStyleOnly(_ draft: LabDraft) -> Bool {
        guard draft.art != .react else { return false }
        return isBlank(draft.html) && !isBlank(draft.css) && isBlank(draft.script)
    }

    static func isBlank(_ text: String) -> Bool {
        text.allSatisfy(\.isWhitespace)
    }

    /// The hosts of the addresses in the texts that the network rule blocks, each once, in order of appearance.
    /// The SVG namespace address is no request, so it is not a host to block.
    static func blockedHosts(in texts: [String]) -> [String] {
        var hosts: [String] = []
        for text in texts {
            for match in text.matches(of: /https?:\/\/[^\s"'<>`)]+/) {
                guard let url = URL(string: String(match.output)), let host = url.host?.lowercased() else { continue }
                if host == "www.w3.org" || WebHostRule.allows(url) { continue }
                if !hosts.contains(host) {
                    hosts.append(host)
                }
            }
        }
        return hosts
    }

    /// True when the markup or the script calls the library.
    static func usesLibrary(_ library: LabLibrary, in draft: LabDraft) -> Bool {
        [draft.html, draft.script].contains { $0.range(of: library.usage, options: .regularExpression) != nil }
    }

    /// True when a script tag of the markup loads the library. The marker must be in the address of its source.
    static func hasScriptTag(_ library: LabLibrary, in html: String) -> Bool {
        html.matches(of: /src\s*=\s*["']([^"']*)["']/).contains { $0.output.1.lowercased().contains(library.marker) }
    }

    /// A React draft without a default export whose component the page cannot find.
    static func hasNoComponent(_ draft: LabDraft) -> Bool {
        guard draft.art == .react, !draft.script.contains("export default") else { return false }
        return WebDocument.componentName(in: WebDocument.stripModules(draft.script)) == nil
    }
}
