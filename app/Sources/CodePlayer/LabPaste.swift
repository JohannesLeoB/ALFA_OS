import Foundation

/// Sorts pasted text by its kind: markup to the HTML tab, style sheets to the CSS tab, scripts to the script tab.
/// The rules follow the browser prototype, with markup first, so that a page with inline scripts stays markup.
public enum LabPaste {
    /// The tab that the pasted text belongs to, or nil when it stays in the open tab.
    public static func target(for text: String) -> LabDraft.Tab? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("<") { return .html }
        let markup = text.contains(/<[a-z!\/]/.ignoresCase())
        if !markup {
            let styleSheet = text.contains(/[.#a-z\-*@:\]][^{}]*\{[^}]*:[^}]*\}/.ignoresCase())
                && !text.contains(/\b(function|const|let|var|=>|document\.|gsap\.)/)
            if styleSheet { return .css }
            let script = text.contains(/\b(function|const|let|=>|document\.|addEventListener|gsap\.)/)
                && !text.contains(/^\s*[.#][\w-]+\s*\{/.anchorsMatchLineEndings())
            if script { return .script }
        }
        return markup ? .html : nil
    }
}
