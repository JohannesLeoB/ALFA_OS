import Foundation

/// The result of resolving a security-scoped bookmark: the folder it points to, and whether the system marks it as outdated.
public struct ResolvedBookmark: Equatable, Sendable {
    public var url: URL
    public var isStale: Bool

    public init(url: URL, isStale: Bool) {
        self.url = url
        self.isStale = isStale
    }
}

/// Makes and resolves the security-scoped bookmarks of the places.
public enum PlaceBookmarks {
    /// The bookmark data for a folder that the user chose.
    public static func make(for folder: URL) throws -> Data {
        try folder.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    /// The folder that bookmark data points to. Throws for data that is not a bookmark.
    public static func resolve(_ data: Data) throws -> ResolvedBookmark {
        var isStale = false
        let url = try URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
        return ResolvedBookmark(url: url, isStale: isStale)
    }
}

/// Whether a place can be opened now. The app asks for this before it reads or writes a place.
public enum PlaceAccess: Equatable, Sendable {
    /// The place opens at this folder.
    case reachable(URL)
    /// The bookmark is outdated: the user chooses the folder again.
    case stale
    /// The place cannot be opened: the bookmark does not resolve, or the folder is gone.
    case unreachable

    /// The access of a place. A place with a bookmark goes through the bookmark. A place without one, inside the
    /// app's own container, uses its path. The app never writes to another place when this one is unreachable.
    public static func check(_ place: Place,
                             resolve: (Data) throws -> ResolvedBookmark = PlaceBookmarks.resolve,
                             folderExists: (URL) -> Bool = PlaceAccess.folderExists) -> PlaceAccess {
        guard let data = place.bookmark else {
            guard let path = place.path else { return .unreachable }
            let url = URL(fileURLWithPath: path, isDirectory: true)
            return folderExists(url) ? .reachable(url) : .unreachable
        }
        guard let resolved = try? resolve(data), folderExists(resolved.url) else { return .unreachable }
        return resolved.isStale ? .stale : .reachable(resolved.url)
    }

    /// Whether the URL is an existing folder.
    public static func folderExists(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
