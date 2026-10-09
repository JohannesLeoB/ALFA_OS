import Foundation

/// The rows of the start window, in the order of the list.
public enum StartRow: String, CaseIterable, Sendable {
    case new, open, example, recent

    /// Catalog key of the row title.
    public var titleKey: String { "start.row.\(rawValue)" }

    /// The recent row needs at least one recent document. The other rows are always enabled.
    public func isEnabled(recentCount: Int) -> Bool {
        self != .recent || recentCount > 0
    }
}

/// Rules of the start window.
public enum StartWindow {
    /// Most recent documents that the list shows.
    public static let recentLimit = 10

    /// The start window shows when the app starts without a document, not when a document opens.
    public static func isShown(openDocuments: Int) -> Bool {
        openDocuments == 0
    }

    /// The names of the recent documents: no duplicates, the first occurrence wins, at most `recentLimit`.
    public static func recentNames(_ names: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for name in names where !name.isEmpty && !seen.contains(name) {
            seen.insert(name)
            out.append(name)
            if out.count == recentLimit { break }
        }
        return out
    }
}
