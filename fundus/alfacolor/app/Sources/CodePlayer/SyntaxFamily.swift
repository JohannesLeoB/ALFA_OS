import ALFAcolorCore
import Foundation

/// The family of highlighting rules that colors a file.
public enum SyntaxFamily: Hashable, Sendable {
    case swift
    /// JavaScript, JSX and the other C-like languages without a rule of their own.
    case script
    /// HTML and CSS: tags, attributes and strings.
    case markup

    /// The family of a language, for a file that has no known extension.
    public static func of(language: CodeLanguage) -> SyntaxFamily {
        switch language {
        case .swiftui: .swift
        case .html, .css, .tailwind: .markup
        case .javascript, .react, .compose, .flutter, .java, .other: .script
        }
    }

    /// The family of a file by its extension. A file with another extension follows the language of its card.
    public static func of(fileName: String, language: CodeLanguage) -> SyntaxFamily {
        switch FileExtension.lowercased(fileName) {
        case "swift": .swift
        case "html", "htm", "css": .markup
        case "js", "jsx", "mjs", "ts", "tsx", "kt", "dart", "java": .script
        default: of(language: language)
        }
    }
}

/// The lower-case extension of a file name, without the dot. Empty when there is none.
enum FileExtension {
    static func lowercased(_ fileName: String) -> String {
        (fileName as NSString).pathExtension.lowercased()
    }
}
