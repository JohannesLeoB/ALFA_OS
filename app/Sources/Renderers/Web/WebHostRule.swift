import Foundation

/// The network rule of web cards. Only these HTTPS hosts load; every other request and navigation is blocked.
public enum WebHostRule {
    public static let allowedHosts = [
        "cdnjs.cloudflare.com",
        "unpkg.com",
        "cdn.jsdelivr.net",
        "cdn.tailwindcss.com",
        "fonts.googleapis.com",
        "fonts.gstatic.com",
    ]

    /// Whether a page may load or open the URL. The page's own about, data and blob URLs pass.
    public static func allows(_ url: URL) -> Bool {
        switch url.scheme?.lowercased() {
        case "about", "data", "blob":
            return true
        case "https":
            guard let host = url.host?.lowercased() else { return false }
            return allowedHosts.contains(host)
        default:
            return false
        }
    }

    /// Matches every URL with a scheme that needs the network, such as https, http, ws or file.
    static let blockPattern = "^[a-z]+://"

    /// Matches the HTTPS URLs of one allowed host. WebKit reads no alternatives in a pattern, so each host has its own.
    static func allowPattern(for host: String) -> String {
        "^https://" + host.replacing(".", with: "\\.") + "/"
    }

    /// WebKit content rules as JSON. The first rule blocks every network URL. One rule per allowed host follows,
    /// and each of those lets its host through again.
    public static var contentRules: String {
        let block = rule(trigger: blockPattern, action: "block")
        let allow = allowedHosts.map { rule(trigger: allowPattern(for: $0), action: "ignore-previous-rules") }
        return "[" + ([block] + allow).joined(separator: ",") + "]"
    }

    /// One rule as JSON. Backslashes in the pattern are escaped for the JSON text.
    private static func rule(trigger: String, action: String) -> String {
        let escaped = trigger.replacing("\\", with: "\\\\")
        return #"{"trigger":{"url-filter":"\#(escaped)"},"action":{"type":"\#(action)"}}"#
    }
}
