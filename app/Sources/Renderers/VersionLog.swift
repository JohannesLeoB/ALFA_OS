/// The versions of one item: the current version and the older ones, oldest first.
/// A save keeps the version it replaces, so no version is lost.
public struct VersionLog<Version: Equatable & Sendable>: Equatable, Sendable {
    public private(set) var current: Version
    /// The versions before the current one, oldest first.
    public private(set) var older: [Version] = []

    public init(current: Version) {
        self.current = current
    }

    /// A log with versions that are already kept, oldest first, for example those of a document.
    public init(current: Version, older: [Version]) {
        self.current = current
        self.older = older
    }

    /// Makes `next` the current version and moves the old one to `older`.
    /// Nothing changes and false is returned when `next` equals the current version.
    @discardableResult
    public mutating func save(_ next: Version) -> Bool {
        guard next != current else { return false }
        older.append(current)
        current = next
        return true
    }
}
