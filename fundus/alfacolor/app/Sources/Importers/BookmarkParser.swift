import Foundation

/// Reads the bookmark files of the browsers. Both readers work on text or data that is already in memory,
/// so they never touch the file system or the network.
public enum BookmarkParser {
    /// The HTML export of Safari, Firefox and Edge (Netscape format). Broken markup is tolerated.
    public static func netscape(_ html: String) -> BookmarkTree {
        NetscapeReader.read(html)
    }

    /// The Bookmarks file of Chrome (JSON, in the profile folder). Throws `BookmarkError.notReadable` for data that is not JSON.
    public static func chrome(_ data: Data) throws -> BookmarkTree {
        try ChromeReader.read(data)
    }
}
