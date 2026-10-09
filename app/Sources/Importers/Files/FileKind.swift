import Foundation
import ALFAcolorCore
import UniformTypeIdentifiers

/// What a file becomes on the board, by its type.
public enum FileKind: Equatable, Sendable {
    case image
    case code(CodeLanguage)
    /// Plain text and Markdown. It becomes a note.
    case text

    private static let codeLanguages: [String: CodeLanguage] = [
        "swift": .swiftui, "html": .html, "htm": .html, "css": .css, "js": .javascript, "mjs": .javascript,
        "jsx": .react, "tsx": .react, "kt": .compose, "dart": .flutter, "java": .java
    ]
    private static let textExtensions: Set<String> = ["txt", "text", "md", "markdown"]

    /// The kind of a file with this extension, or nil for a file the board does not take.
    /// Code is known by extension. Other source code becomes a card of the language `other`.
    public static func kind(forExtension fileExtension: String) -> FileKind? {
        let ext = fileExtension.lowercased()
        if let language = codeLanguages[ext] { return .code(language) }
        if textExtensions.contains(ext) { return .text }
        guard let type = UTType(filenameExtension: ext) else { return nil }
        if type.conforms(to: .image) { return .image }
        if type.conforms(to: .sourceCode) { return .code(.other) }
        if type.conforms(to: .text) { return .text }
        return nil
    }
}
