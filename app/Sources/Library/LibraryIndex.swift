import Foundation
import ALFAcolorCore

/// The search index over all items of all rooms. It is a cache: it is built from the board and keeps
/// no value that is not in the board. Building it again from the same board gives the same results.
public struct LibraryIndex: Sendable {
    /// One item as the index keeps it.
    struct Record: Sendable {
        let ref: ItemRef
        let kind: ItemKind
        /// Searchable text in normalized form (see `normalize`), as UTF-8 bytes.
        let text: [UInt8]
    }

    private(set) var records: [Record]

    /// Reads every item of every room, in the order of the board.
    public init(board: Board) {
        var records: [Record] = []
        for space in board.spaces {
            records.reserveCapacity(records.count + space.items.count)
            for item in space.items {
                records.append(Record(ref: ItemRef(spaceID: space.id, itemID: item.id),
                                      kind: ItemKind(content: item.content),
                                      text: Self.bytes(Self.searchText(of: item))))
            }
        }
        self.records = records
    }

    /// Number of indexed items.
    public var count: Int { records.count }

    /// Items whose searchable text contains every word of `text`, in board order.
    /// Case and diacritics do not matter. An empty text matches every item.
    public func search(text: String) -> [ItemRef] {
        let words = Self.normalize(text).split(whereSeparator: \.isWhitespace).map { Self.bytes(String($0)) }
        guard !words.isEmpty else { return records.map(\.ref) }
        return records.compactMap { record in
            words.allSatisfy { Self.contains(record.text, $0) } ? record.ref : nil
        }
    }

    // MARK: Text

    /// The text the search looks at: the title, the note or text, the link address and its note, and the code.
    static func searchText(of item: Item) -> String {
        var parts = [item.title]
        switch item.content {
        case .code(_, let files, _):
            for name in files.keys.sorted() { parts.append(files[name] ?? "") }
        case .note(let text), .text(let text, _):
            parts.append(text)
        case .link(let url, let note):
            parts.append(url.absoluteString)
            if let note { parts.append(note) }
        case .swatch(_, let name):
            if let name { parts.append(name) }
        case .image, .shape, .frame, .group:
            break
        }
        return parts.joined(separator: "\n")
    }

    /// Lower case, no diacritics. Used on both sides of a comparison.
    static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    private static func bytes(_ text: String) -> [UInt8] { Array(normalize(text).utf8) }

    /// Whether `needle` occurs in `haystack`. Both are UTF-8 bytes of normalized text. An empty needle always occurs.
    static func contains(_ haystack: [UInt8], _ needle: [UInt8]) -> Bool {
        guard let first = needle.first else { return true }
        let last = haystack.count - needle.count
        guard last >= 0 else { return false }
        var start = 0
        while start <= last {
            if haystack[start] == first {
                var offset = 1
                while offset < needle.count, haystack[start + offset] == needle[offset] { offset += 1 }
                if offset == needle.count { return true }
            }
            start += 1
        }
        return false
    }
}
