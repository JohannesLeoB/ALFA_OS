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
        let art: Art
        switch card.language {
        case .html, .css, .javascript: art = .html
        case .tailwind: art = .tailwind
        case .react: art = .react
        case .swiftui, .compose, .flutter, .java, .other: return nil
        }
        let names = card.files.keys.sorted()
        let isStyle = { (name: String) in name.lowercased().hasSuffix(".css") }
        let markupName: String? = art == .react ? nil
            : names.contains("index.html") ? "index.html"
            : names.first { $0.lowercased().hasSuffix(".html") }
        self.art = art
        self.width = previewWidth ?? CodeCardLayout.defaultPageWidth
        html = markupName.flatMap { card.files[$0] } ?? ""
        css = names.filter(isStyle).compactMap { card.files[$0] }.joined(separator: "\n")
        script = names.filter { $0 != markupName && !isStyle($0) }.compactMap { card.files[$0] }.joined(separator: "\n")
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

    private func fileName(for tab: Tab) -> String {
        switch tab {
        case .html: "index.html"
        case .css: "style.css"
        case .script: art == .react ? "component.jsx" : "script.js"
        }
    }
}
