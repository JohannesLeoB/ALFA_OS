import Foundation
import Importers

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

/// What the lab reads from a text: the art it suggests, and whether the page can play it.
public struct LabReading: Equatable, Sendable {
    public let classification: CodeClassification

    public init(_ text: String) {
        classification = PasteDetector.classify(text)
    }

    /// The art that the text asks for. nil for a piece such as a style sheet or a script, and for code that does not run.
    public var art: LabDraft.Art? {
        switch classification.kind {
        case .react: .react
        case .tailwind: .tailwind
        case .html, .svg: .html
        case .css, .script, .json, .foreign, .notCode: nil
        }
    }
}

/// Code that the page cannot play: a language that needs a translation first, data, or a note.
public enum LabBlock: String, Equatable, Sendable {
    case swift, kotlin, java, dart, python, json, note
}
