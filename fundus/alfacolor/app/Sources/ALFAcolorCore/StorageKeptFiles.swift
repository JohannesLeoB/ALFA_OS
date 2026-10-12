import Foundation

/// The old files the user chose to keep where they are, by their paths. For these files the app does not ask again.
/// The app stores `paths` and restores them with `init(paths:)`.
public struct StorageKeptFiles: Sendable {
    private var kept: Set<String>

    public init(paths: [String] = []) {
        kept = Set(paths)
    }

    /// The remembered paths, sorted, for storing.
    public var paths: [String] { kept.sorted() }

    /// Remembers that the user keeps this old file where it is.
    public mutating func keep(_ url: URL) {
        kept.insert(url.standardizedFileURL.path)
    }

    /// Whether the user chose to keep this old file where it is.
    public func contains(_ url: URL) -> Bool {
        kept.contains(url.standardizedFileURL.path)
    }
}
