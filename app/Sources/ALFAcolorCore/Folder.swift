import Foundation

/// A folder of the library. It spans all rooms. A fixed folder is a list of items the user picked; a smart folder
/// is a saved filter and shows whatever matches it. Both are part of the document.
public struct Folder: Codable, Hashable, Sendable, Identifiable {
    /// Stable ID, so that renaming changes nothing else.
    public var id: String
    public var name: String
    public var rule: FolderRule

    public init(id: String, name: String, rule: FolderRule) {
        self.id = id
        self.name = name
        self.rule = rule
    }
}

/// What a folder shows.
public enum FolderRule: Codable, Hashable, Sendable {
    /// Items in the order they were added. An item that no longer exists is skipped, and is not removed from the list.
    case fixed([ItemRef])
    /// Items that match the filter.
    case smart(LibraryFilter)
}
