import Foundation
import ALFAcolorCore

/// Reads a file or folder from disk into a piece.
enum FileReader {
    /// Files above this size ask first.
    static let confirmAbove = 20 * 1024 * 1024
    /// Files above this size are never taken, also after the user agreed.
    static let hardLimit = 256 * 1024 * 1024

    enum Result: Equatable, Sendable {
        case piece(Piece)
        case skipped(SkippedFile)
        case large(LargeFile)
    }

    /// `allowLarge` lists files above the limit that the user agreed to take.
    /// The file may sit outside the sandbox container. The system grants access to files that were dropped or pasted,
    /// and the grant is held while the file is read.
    static func read(_ url: URL, allowLarge: Set<URL>, now: Date) -> Result {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey]) else {
            return .skipped(SkippedFile(url: url, reason: .unreadable))
        }
        guard values.isDirectory != true, let kind = FileKind.kind(forExtension: url.pathExtension) else {
            return .skipped(SkippedFile(url: url, reason: .unsupportedType))
        }
        guard let bytes = byteCount(of: url, known: values.fileSize) else {
            return .skipped(SkippedFile(url: url, reason: .unreadable))
        }
        if bytes > hardLimit { return .skipped(SkippedFile(url: url, reason: .tooLarge)) }
        if bytes > confirmAbove, !allowLarge.contains(url) { return .large(LargeFile(url: url, bytes: bytes)) }
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return .skipped(SkippedFile(url: url, reason: .unreadable)) }

        let name = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension.lowercased()
        let source = Source(file: url.lastPathComponent, via: "file", importedAt: now)
        switch kind {
        case .image:
            return .piece(Piece(title: name, body: .image(data, fileExtension: ext, pixels: ImageProbe.pixelSize(of: data)), tags: [], source: source))
        case .code(let language):
            guard let text = decode(data) else { return .skipped(SkippedFile(url: url, reason: .unsupportedType)) }
            let resolved = language == .html && PasteDetector.isTailwind(text) ? CodeLanguage.tailwind : language
            return .piece(Piece(title: name, body: .content(.code(language: resolved, files: [url.lastPathComponent: text], previewWidth: nil)),
                                tags: [ext], source: source))
        case .text:
            guard let text = decode(data) else { return .skipped(SkippedFile(url: url, reason: .unsupportedType)) }
            return .piece(Piece(title: name, body: .content(.note(text: text)), tags: [ext], source: source))
        }
    }

    /// The size of a file: the size the system reports, or, when it reports none, the size measured by reading to the end.
    /// Nil when the file cannot be measured.
    static func byteCount(of url: URL, known: Int?) -> Int? {
        if let known { return known }
        guard let handle = try? FileHandle(forReadingFrom: url), let end = try? handle.seekToEnd() else { return nil }
        try? handle.close()
        return Int(clamping: end)
    }

    /// The text of a file as UTF-8, or as Latin-1 when it is no UTF-8. Bytes with a zero are no text.
    static func decode(_ data: Data) -> String? {
        guard !data.contains(0) else { return nil }
        return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
    }
}
