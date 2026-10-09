import Foundation
import ALFAcolorCore

/// The links of one folder of a bookmark file, as indices into the pieces of the result.
public struct BookmarkGroup: Equatable, Sendable {
    public var name: String
    public var pieceIndices: [Int]

    public init(name: String, pieceIndices: [Int]) {
        self.name = name
        self.pieceIndices = pieceIndices
    }
}

/// What a bookmark file gives for the board.
public struct BookmarkResult: Equatable, Sendable {
    public var pieces: [Piece]
    /// One group for each folder that has links, in the order of the file.
    public var groups: [BookmarkGroup]
    /// Links whose address was already taken earlier in the same file.
    public var duplicates: Int
    /// Entries the reader did not take, as counted by the reader.
    public var skipped: Int
    /// True when a limit of the reader cut the file.
    public var truncated: Bool

    public init(pieces: [Piece], groups: [BookmarkGroup], duplicates: Int, skipped: Int, truncated: Bool) {
        self.pieces = pieces
        self.groups = groups
        self.duplicates = duplicates
        self.skipped = skipped
        self.truncated = truncated
    }
}

/// Turns the links of a bookmark file into pieces. Each link is a piece with its folder path as tags.
public enum BookmarkImport {
    public static func pieces(from tree: BookmarkTree, now: Date) -> BookmarkResult {
        var result = BookmarkResult(pieces: [], groups: [], duplicates: 0, skipped: tree.skipped, truncated: tree.truncated)
        var seen = Set<String>()
        collect(tree.root, tags: [], now: now, seen: &seen, result: &result)
        return result
    }

    private static func collect(_ folder: BookmarkFolder, tags: [String], now: Date, seen: inout Set<String>,
                                result: inout BookmarkResult) {
        var indices: [Int] = []
        for link in folder.links {
            guard seen.insert(link.url.absoluteString).inserted else {
                result.duplicates += 1
                continue
            }
            indices.append(result.pieces.count)
            let source = Source(url: link.url, via: "bookmark", importedAt: now)
            result.pieces.append(Piece(title: link.title, body: .content(.link(url: link.url, note: nil)), tags: tags, source: source))
        }
        if !indices.isEmpty {
            result.groups.append(BookmarkGroup(name: folder.name, pieceIndices: indices))
        }
        for sub in folder.folders {
            let subTags = sub.name.isEmpty ? tags : tags + [sub.name]
            collect(sub, tags: subTags, now: now, seen: &seen, result: &result)
        }
    }
}
