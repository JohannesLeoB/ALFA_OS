import Foundation

/// The five output formats of a token set. Each one is a pure function of the set; the view only shows and saves the text.
public enum TokenFormat: String, CaseIterable, Sendable {
    case dtcg, css, swiftUI, tailwind, compose

    /// A suggested file name for saving the text.
    public var fileName: String {
        switch self {
        case .dtcg: "tokens.json"
        case .css: "tokens.css"
        case .swiftUI: "Tokens.swift"
        case .tailwind: "tailwind.config.js"
        case .compose: "Tokens.kt"
        }
    }

    /// The text of the format: DTCG JSON, CSS variables, SwiftUI source, Tailwind config, or Compose source.
    public func text(_ set: TokenSet) throws -> String {
        switch self {
        case .dtcg: try TokenExport.dtcg(set)
        case .css: TokenExport.css(set)
        case .swiftUI: TokenExport.swiftUI(set)
        case .tailwind: TailwindExport.config(set)
        case .compose: ComposeExport.kotlin(set)
        }
    }
}
