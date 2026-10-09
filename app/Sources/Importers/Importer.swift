import Foundation
import ALFAcolorCore

/// Turns what the system handed over into pieces. It reads files, so it can take time; it runs off the main thread.
public enum Importer {
    /// `allowLarge` lists files above the size limit that the user agreed to take.
    /// Sources that give nothing (blank text) are left out without a message.
    public static func read(_ sources: [ImportSource], entry: ImportEntry, allowLarge: Set<URL> = [],
                            now: Date = Board.currentTime()) async -> ImportOutcome {
        var outcome = ImportOutcome()
        for source in sources {
            switch source {
            case .text(let text):
                if let detected = PasteDetector.detect(text) {
                    outcome.pieces += pieces(for: detected, entry: entry, now: now)
                }
            case .image(let data, let fileExtension, let name):
                outcome.pieces.append(imagePiece(data, fileExtension: fileExtension, name: name, entry: entry, now: now))
            case .file(let url):
                switch FileReader.read(url, allowLarge: allowLarge, now: now) {
                case .piece(let piece): outcome.pieces.append(piece)
                case .skipped(let skipped): outcome.skipped.append(skipped)
                case .large(let large): outcome.large.append(large)
                }
            }
        }
        return outcome
    }

    /// The pieces for a detected text. A list of colors gives one piece for each color.
    public static func pieces(for detected: Detected, entry: ImportEntry, now: Date = Board.currentTime()) -> [Piece] {
        let origin = Source(via: entry.rawValue, importedAt: now)
        switch detected {
        case .link(let url, _):
            var source = origin
            source.url = url
            return [Piece(body: .content(.link(url: url, note: nil)), source: source)]
        case .colors(let colors):
            return colors.map { Piece(title: $0.name ?? "", body: .content(.swatch(hex: $0.hex, name: $0.name)), source: origin) }
        case .code(let snippet):
            let width: Double? = snippet.language == .swiftui ? nil : Self.previewWidth
            let content = Content.code(language: snippet.language, files: [snippet.fileName: snippet.text], previewWidth: width)
            return [Piece(body: .content(content), source: origin)]
        case .note(let text):
            return [Piece(body: .content(.note(text: text)), source: origin)]
        }
    }

    /// The width of the preview of web code, in points.
    static let previewWidth = 1280.0

    /// A piece for image bytes. Other formats than PNG, JPEG and GIF-like web formats stay as they are, except TIFF,
    /// which the clipboard uses for screenshots; it becomes PNG.
    static func imagePiece(_ data: Data, fileExtension: String, name: String?, entry: ImportEntry, now: Date) -> Piece {
        var bytes = data
        var ext = fileExtension.lowercased()
        if ext == "tiff" || ext == "tif", let png = ImageProbe.pngData(from: data) {
            bytes = png
            ext = "png"
        }
        let source = Source(via: entry.rawValue, importedAt: now)
        return Piece(title: name ?? "", body: .image(bytes, fileExtension: ext, pixels: ImageProbe.pixelSize(of: bytes)), source: source)
    }
}
