import Foundation

/// The text or data of a bookmark file, as the caller has read it.
public enum BookmarkInput: Equatable, Sendable {
    /// The HTML export of Safari, Firefox or Edge.
    case netscape(String)
    /// The Bookmarks file of Chrome (JSON).
    case chrome(Data)
}

public extension BookmarkImport {
    /// Reads a bookmark file from its text or data and gives the pieces and groups. Only broken Chrome data throws.
    static func read(_ input: BookmarkInput, now: Date) throws -> BookmarkResult {
        switch input {
        case .netscape(let html):
            return pieces(from: BookmarkParser.netscape(html), now: now)
        case .chrome(let data):
            return pieces(from: try BookmarkParser.chrome(data), now: now)
        }
    }
}
