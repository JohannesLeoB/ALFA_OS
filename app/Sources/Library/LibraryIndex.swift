import Foundation
import ALFAcolorCore
import ColorLab
import Tokens

/// The search index over all items of all rooms. It is a cache: it is built from the board and keeps
/// no value that is not in the board. Building it again from the same board gives the same results.
public struct LibraryIndex: Sendable {
    /// One item as the index keeps it. Text is normalized (see `normalize`) and kept as UTF-8 bytes.
    struct Record: Sendable {
        let ref: ItemRef
        let kind: ItemKind
        let text: [UInt8]
        let tags: Set<String>
        let via: String?
        let hosts: Set<String>
        let license: String?
        /// True when the item may be used freely (see `License.isFreeItem`).
        let free: Bool
        let importedAt: Date?
        let colors: [Lab]

        init(space: Space, item: Item) {
            ref = ItemRef(spaceID: space.id, itemID: item.id)
            kind = ItemKind(item.content)
            text = LibraryIndex.bytes(LibraryIndex.searchText(of: item))
            tags = Set(item.tags.map(LibraryIndex.normalize))
            via = item.source.map { LibraryIndex.normalize($0.via) }
            hosts = Set(LibraryIndex.hosts(of: item).map(LibraryIndex.normalize))
            license = item.source?.license.map(LibraryIndex.normalize)
            free = License.isFreeItem(item.source)
            importedAt = item.source?.importedAt
            colors = LibraryIndex.colors(of: item)
        }
    }

    private(set) var records: [Record]

    /// Reads every item of every room, in the order of the board.
    public init(board: Board) {
        var records: [Record] = []
        for space in board.spaces {
            records.reserveCapacity(records.count + space.items.count)
            for item in space.items {
                records.append(Record(space: space, item: item))
            }
        }
        self.records = records
    }

    /// Number of indexed items.
    public var count: Int { records.count }

    /// Items whose searchable text contains every word of `text`, in board order.
    /// Case and diacritics do not matter. An empty text matches every item.
    public func search(text: String) -> [ItemRef] {
        search(LibraryFilter(text: text))
    }

    /// Items that meet every condition of `filter`, in board order. An empty filter matches every item.
    /// A colour that is not a hex colour matches nothing.
    public func search(_ filter: LibraryFilter) -> [ItemRef] {
        let words = Self.normalize(filter.text).split(whereSeparator: \.isWhitespace).map { Self.bytes(String($0)) }
        let tags = Set(filter.tags.map(Self.normalize))
        let via = filter.via.map(Self.normalize)
        let host = filter.host.map(Self.normalize)
        let license = filter.license.map(Self.normalize)
        var target: Lab?
        if let color = filter.color {
            guard let rgb = RGB(hex: color.hex) else { return [] }
            target = ColorMath.lab(rgb)
        }
        return records.compactMap { record in
            guard filter.kinds.isEmpty || filter.kinds.contains(record.kind) else { return nil }
            guard words.allSatisfy({ Self.contains(record.text, $0) }) else { return nil }
            guard tags.isSubset(of: record.tags) else { return nil }
            if let via, record.via != via { return nil }
            if let host, !record.hosts.contains(host) { return nil }
            if let license, !(record.license?.contains(license) ?? false) { return nil }
            if filter.freeLicenseOnly == true, !record.free { return nil }
            if filter.importedFrom != nil || filter.importedUntil != nil {
                guard let date = record.importedAt else { return nil }
                if let from = filter.importedFrom, date < from { return nil }
                if let until = filter.importedUntil, date > until { return nil }
            }
            if let target, let color = filter.color {
                guard record.colors.contains(where: { ColorMath.deltaE($0, target) <= color.distance }) else { return nil }
            }
            return record.ref
        }
    }

    // MARK: Reading the item

    /// The text the search looks at: the title, the note or text, the link address and its note, the code,
    /// and the texts of the notes on the item.
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
        parts += item.notes.map(\.text)
        return parts.joined(separator: "\n")
    }

    /// The hosts of an item: of its source address and, for a link, of the link address.
    static func hosts(of item: Item) -> [String] {
        var out: [String] = []
        if let host = item.source?.url?.host { out.append(host) }
        if case .link(let url, _) = item.content, let host = url.host { out.append(host) }
        return out
    }

    /// The colours of an item: a swatch, and the fill and stroke of a shape. Other items have none.
    static func colors(of item: Item) -> [Lab] {
        var hexes: [String] = []
        switch item.content {
        case .swatch(let hex, _): hexes.append(hex)
        case .shape(_, let style):
            if let fill = style.fill { hexes.append(fill) }
            if let stroke = style.stroke { hexes.append(stroke) }
        default: break
        }
        return hexes.compactMap { RGB(hex: $0).map(ColorMath.lab) }
    }

    // MARK: Text

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
