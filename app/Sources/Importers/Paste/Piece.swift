import Foundation
import ALFAcolorCore
import BoardModel

/// Where an import came from.
public enum ImportEntry: String, Sendable {
    case paste, drop
}

/// Something to import, as the system hands it over.
public enum ImportSource: Equatable, Sendable {
    /// Image bytes, for example a screenshot from the clipboard. `name` is a suggested file name without extension.
    case image(Data, fileExtension: String, name: String?)
    case text(String)
    /// A file or a folder. The bytes are read later.
    case file(URL)
}

/// One thing to put on the canvas, before it has a place and an ID.
public struct Piece: Equatable, Sendable {
    public enum Body: Equatable, Sendable {
        /// Image bytes with their size in pixels, if it is known. The bytes go to the asset store of the document.
        case image(Data, fileExtension: String, pixels: CanvasSize?)
        case content(Content)
    }

    public var title: String
    public var body: Body
    public var tags: [String]
    public var source: Source

    public init(title: String = "", body: Body, tags: [String] = [], source: Source) {
        self.title = title
        self.body = body
        self.tags = tags
        self.source = source
    }
}

/// A file that was not taken, and why.
public struct SkippedFile: Equatable, Sendable {
    public enum Reason: String, Equatable, Sendable {
        /// The type is not one the board takes (a folder, a movie, a binary file).
        case unsupportedType
        /// The file could not be read.
        case unreadable
    }

    public var url: URL
    public var reason: Reason
    public init(url: URL, reason: Reason) { self.url = url; self.reason = reason }
}

/// A file above the size limit. It is taken only after the user agrees.
public struct LargeFile: Equatable, Sendable {
    public var url: URL
    public var bytes: Int
    public init(url: URL, bytes: Int) { self.url = url; self.bytes = bytes }
}

/// What reading a set of sources gave.
public struct ImportOutcome: Equatable, Sendable {
    public var pieces: [Piece] = []
    public var skipped: [SkippedFile] = []
    public var large: [LargeFile] = []
    public init() {}
    public var isEmpty: Bool { pieces.isEmpty && skipped.isEmpty && large.isEmpty }
}
