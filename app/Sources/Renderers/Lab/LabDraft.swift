import ALFAcolorCore

/// The code of the lab: one text per tab, the art of the page and the width of the page.
/// It reads a web card and writes its files back, so the lab works on the files of a card.
public struct LabDraft: Equatable, Sendable {
    /// The art of the page. HTML takes markup, styles and scripts. Tailwind adds its script. React takes JSX.
    public enum Art: String, CaseIterable, Sendable {
        case html, tailwind, react
    }

    /// A tab of the source. The script tab holds JavaScript, or JSX for React.
    public enum Tab: String, CaseIterable, Sendable {
        case html, css, script
    }

    public var art: Art
    /// The page width in points. 0 fills the frame of the lab.
    public var width: Double
    public var html: String
    public var css: String
    public var script: String

    public init(art: Art = .html, width: Double = 0, html: String = "", css: String = "", script: String = "") {
        self.art = art
        self.width = width
        self.html = html
        self.css = css
        self.script = script
    }

    /// The draft of a web card. nil for a card that is not web code, such as SwiftUI.
    /// A card with several files of one kind shows them joined in one tab.
    public init?(card: CodeCard, previewWidth: Double?) {
        guard let art = Self.art(of: card.language) else { return nil }
        let files = Self.tabFiles(of: card) ?? [:]
        self.art = art
        width = previewWidth ?? CodeCardLayout.defaultPageWidth
        html = Self.joined(files[.html] ?? [], in: card)
        css = Self.joined(files[.css] ?? [], in: card)
        script = Self.joined(files[.script] ?? [], in: card)
    }

    /// The tabs of the art. React has no markup tab.
    public var tabs: [Tab] {
        Tab.allCases.filter { art != .react || $0 != .html }
    }

    public func text(_ tab: Tab) -> String {
        switch tab {
        case .html: html
        case .css: css
        case .script: script
        }
    }

    public mutating func setText(_ text: String, for tab: Tab) {
        switch tab {
        case .html: html = text
        case .css: css = text
        case .script: script = text
        }
    }

    /// The language of the card that the draft makes.
    public var language: CodeLanguage {
        switch art {
        case .html: .html
        case .tailwind: .tailwind
        case .react: .react
        }
    }

    /// The files of the card by name. A tab without text has no file.
    public var files: [String: String] {
        var result: [String: String] = [:]
        for tab in tabs where !text(tab).isEmpty {
            result[fileName(for: tab)] = text(tab)
        }
        return result
    }

    /// The card that the draft makes, ready for the renderers.
    public var card: CodeCard {
        CodeCard(language: language, files: files)
    }

    /// The card that the draft makes on top of `board`, the card as it is on the board.
    /// The file names and the language of the board stay while the art stays. A tab whose text did not change keeps its files.
    /// A tab whose text changed is written into its first file, and its other files are removed.
    public func card(over board: CodeCard) -> CodeCard {
        let boardTabs = Self.tabFiles(of: board) ?? [:]
        // A card that is not web code has no tabs, so the draft brings its own files.
        var files = Self.tabFiles(of: board) == nil ? [:] : board.files
        for tab in Tab.allCases {
            let names = boardTabs[tab] ?? []
            let shown = tabs.contains(tab) ? text(tab) : ""
            if !names.isEmpty, Self.joined(names, in: board) == shown { continue }
            for name in names { files[name] = nil }
            if !shown.isEmpty { files[names.first ?? fileName(for: tab)] = shown }
        }
        let keepsLanguage = Self.art(of: board.language) == art
        return CodeCard(language: keepsLanguage ? board.language : language, files: files)
    }

    /// The art of a web language. nil for a language that the lab does not show.
    static func art(of language: CodeLanguage) -> Art? {
        switch language {
        case .html, .css, .javascript: .html
        case .tailwind: .tailwind
        case .react: .react
        case .swiftui, .compose, .flutter, .java, .other: nil
        }
    }

    /// The file names of a web card by tab, in the order that the draft joins them. nil for a card that is not web code.
    static func tabFiles(of card: CodeCard) -> [Tab: [String]]? {
        guard let art = art(of: card.language) else { return nil }
        let names = card.files.keys.sorted()
        let markup: String? = art == .react ? nil
            : names.contains("index.html") ? "index.html"
            : names.first { $0.lowercased().hasSuffix(".html") }
        var result: [Tab: [String]] = [:]
        for name in names {
            if name == markup {
                result[.html, default: []].append(name)
            } else if isStyle(name) {
                result[.css, default: []].append(name)
            } else {
                result[.script, default: []].append(name)
            }
        }
        return result
    }

    private static func isStyle(_ name: String) -> Bool {
        name.lowercased().hasSuffix(".css")
    }

    private static func joined(_ names: [String], in card: CodeCard) -> String {
        names.compactMap { card.files[$0] }.joined(separator: "\n")
    }

    private func fileName(for tab: Tab) -> String {
        switch tab {
        case .html: "index.html"
        case .css: "style.css"
        case .script: art == .react ? "component.jsx" : "script.js"
        }
    }
}
