import Foundation

/// Why a bookmark file could not be read as a whole.
public enum BookmarkError: Error, Equatable, Sendable {
    /// The data is not a bookmark file of the expected format, for example broken JSON.
    case notReadable
}

/// A link of a bookmark file: its title, its web address and, if the file has one, the time it was added.
public struct BookmarkLink: Equatable, Sendable {
    public var title: String
    public var url: URL
    public var added: Date?

    public init(title: String, url: URL, added: Date? = nil) {
        self.title = title
        self.url = url
        self.added = added
    }
}

/// A folder of a bookmark file, with its folders and links in the order of the file.
public struct BookmarkFolder: Equatable, Sendable {
    public var name: String
    public var folders: [BookmarkFolder]
    public var links: [BookmarkLink]

    public init(name: String, folders: [BookmarkFolder] = [], links: [BookmarkLink] = []) {
        self.name = name
        self.folders = folders
        self.links = links
    }
}

/// The bookmarks of one file.
public struct BookmarkTree: Equatable, Sendable {
    /// The top level. Its name is empty; a Chrome file puts its three roots into it as folders.
    public var root: BookmarkFolder
    /// Entries that are not taken: addresses that are not web addresses and links without an address.
    public var skipped: Int
    /// True when a limit cut the file.
    public var truncated: Bool

    public init(root: BookmarkFolder = BookmarkFolder(name: ""), skipped: Int = 0, truncated: Bool = false) {
        self.root = root
        self.skipped = skipped
        self.truncated = truncated
    }
}
