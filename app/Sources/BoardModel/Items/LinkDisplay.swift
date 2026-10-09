import Foundation

/// The parts of a link address that a card shows.
enum LinkDisplay {
    /// The host without a leading "www.", in lower case. The whole address when there is no host.
    static func domain(of url: URL) -> String {
        guard let host = url.host(percentEncoded: false), !host.isEmpty else { return url.absoluteString }
        let lower = host.lowercased()
        return lower.hasPrefix("www.") && lower.count > 4 ? String(lower.dropFirst(4)) : lower
    }

    /// The path and the query. "/" alone is empty.
    static func path(of url: URL) -> String {
        let path = url.path(percentEncoded: false)
        let query = url.query(percentEncoded: false).map { "?" + $0 } ?? ""
        return path == "/" ? query : path + query
    }

    static func content(url: URL, note: String?) -> LinkContent {
        let clean = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        return LinkContent(url: url, domain: domain(of: url), path: path(of: url), note: clean?.isEmpty == false ? clean : nil)
    }
}
