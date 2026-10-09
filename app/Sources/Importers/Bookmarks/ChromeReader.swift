import Foundation

/// Reads the Chrome bookmark file (JSON). Unknown fields and missing roots are no error.
enum ChromeReader {
    /// Chrome counts time in microseconds since 1601. Unix time starts this many seconds later.
    private static let epochOffset: Double = 11_644_473_600

    static func read(_ data: Data) throws -> BookmarkTree {
        guard let object = try? JSONSerialization.jsonObject(with: data), let top = object as? [String: Any] else {
            throw BookmarkError.notReadable
        }
        let roots = top["roots"] as? [String: Any] ?? [:]
        var tree = BookmarkTree()
        for (key, fallback) in [("bookmark_bar", "Bookmarks bar"), ("other", "Other bookmarks"), ("synced", "Mobile bookmarks")] {
            guard let node = roots[key] as? [String: Any] else { continue }
            var folder = BookmarkFolder(name: name(of: node) ?? fallback)
            fill(&folder, from: node, skipped: &tree.skipped)
            tree.root.folders.append(folder)
        }
        return tree
    }

    private static func fill(_ folder: inout BookmarkFolder, from node: [String: Any], skipped: inout Int) {
        for child in node["children"] as? [Any] ?? [] {
            guard let item = child as? [String: Any] else {
                skipped += 1
                continue
            }
            switch item["type"] as? String {
            case "folder":
                var sub = BookmarkFolder(name: name(of: item) ?? "")
                fill(&sub, from: item, skipped: &skipped)
                folder.folders.append(sub)
            case "url":
                if let link = link(from: item) {
                    folder.links.append(link)
                } else {
                    skipped += 1
                }
            default:
                skipped += 1
            }
        }
    }

    private static func link(from item: [String: Any]) -> BookmarkLink? {
        guard let text = item["url"] as? String, let url = BookmarkText.webURL(text) else { return nil }
        return BookmarkLink(title: BookmarkText.tidy(item["name"] as? String ?? ""), url: url, added: added(item["date_added"]))
    }

    private static func name(of item: [String: Any]) -> String? {
        let text = BookmarkText.tidy(item["name"] as? String ?? "")
        return text.isEmpty ? nil : text
    }

    /// The date added. Chrome writes it as text; a number is read as well.
    private static func added(_ value: Any?) -> Date? {
        let microseconds: Double?
        if let number = value as? NSNumber {
            microseconds = number.doubleValue
        } else {
            microseconds = (value as? String).flatMap { Double($0) }
        }
        guard let microseconds, microseconds.isFinite else { return nil }
        return Date(timeIntervalSince1970: microseconds / 1_000_000 - epochOffset)
    }
}
