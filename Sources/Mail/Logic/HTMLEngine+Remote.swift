import Foundation

extension HTMLEngine {
    private static let remoteAttributes: Set<String> = ["src", "srcset", "background", "poster", "data"]
    private static let droppedTags: Set<String> = ["script", "link", "iframe", "frame", "embed", "object", "base"]
    private static let droppedEnds: Set<String> = ["script", "iframe", "frame", "embed", "object"]
    private static let cssURL = #"url\(\s*['"]?\s*(?:https?:)?//[^)]*\)"#
    private static let cssImport = #"@import[^;]*;?"#

    static func hasRemote(_ tokens: [HTMLToken]) -> Bool {
        tokens.contains { token in
            switch token.kind {
            case .text, .end: false
            case .raw: cssRemote(token.raw)
            case .start: startsRemote(token)
            }
        }
    }

    static func blocked(_ tokens: [HTMLToken]) -> String {
        var out = ""
        var owner = ""
        for token in tokens {
            switch token.kind {
            case .text:
                out += token.raw
            case .raw:
                if owner != "script" { out += owner == "style" ? clean(css: token.raw) : token.raw }
            case .start:
                owner = token.name
                out += neutral(token)
            case .end:
                if !droppedEnds.contains(token.name) { out += token.raw }
            }
        }
        return out
    }

    static func isRemote(_ value: String) -> Bool {
        let lower = value.lowercased()
        return lower.contains("http://") || lower.contains("https://") || lower.trimmingCharacters(in: .whitespaces).hasPrefix("//")
    }

    private static func startsRemote(_ token: HTMLToken) -> Bool {
        if token.name == "link", isRemote(token.attributes["href"] ?? "") { return true }
        if token.attributes.contains(where: { remoteAttributes.contains($0.key) && isRemote($0.value) }) { return true }
        return token.attributes["style"].map(cssRemote) ?? false
    }

    private static func cssRemote(_ css: String) -> Bool {
        css.range(of: cssURL, options: [.regularExpression, .caseInsensitive]) != nil
            || css.range(of: cssImport, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func clean(css: String) -> String {
        css.replacingOccurrences(of: cssImport, with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: cssURL, with: "url()", options: [.regularExpression, .caseInsensitive])
    }

    private static func neutral(_ token: HTMLToken) -> String {
        if droppedTags.contains(token.name) { return "" }
        if token.name == "meta", token.attributes["http-equiv"]?.lowercased() == "refresh" { return "" }
        var attributes: [String: String] = [:]
        var changed = false
        for (key, value) in token.attributes {
            if remoteAttributes.contains(key), isRemote(value) {
                changed = true
            } else if key == "style", cssRemote(value) {
                attributes[key] = clean(css: value)
                changed = true
            } else {
                attributes[key] = value
            }
        }
        guard changed else { return token.raw }
        let pairs = attributes.sorted { $0.key < $1.key }.map { " \($0.key)=\"\($0.value.replacingOccurrences(of: "\"", with: "&quot;"))\"" }
        return "<" + token.name + pairs.joined() + (token.selfClosing ? " />" : ">")
    }
}
