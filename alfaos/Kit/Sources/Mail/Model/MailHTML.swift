import Foundation
import ShellCore

public enum MailInlineSource: Equatable, Sendable {
    case embedded(Data, mime: String)
    case attachment(String)
}

public enum MailNavigation: Equatable, Sendable {
    case allow
    case open
    case cancel
}

public struct MailHTMLStyle: Equatable, Sendable {
    public let text: RGB
    public let secondary: RGB
    public let line: RGB
    public let background: RGB
    public let fontSize: Double
    public let lineHeight: Double
    public let quoteBar: Double
    public let quoteGap: Double

    public init(text: RGB, secondary: RGB, line: RGB, background: RGB, fontSize: Double, lineHeight: Double,
                quoteBar: Double, quoteGap: Double) {
        self.text = text
        self.secondary = secondary
        self.line = line
        self.background = background
        self.fontSize = fontSize
        self.lineHeight = lineHeight
        self.quoteBar = quoteBar
        self.quoteGap = quoteGap
    }
}

public enum MailHTML {
    public static let ruleListID = "alfa.mail.block-remote"
    public static let inlineScheme = "cid"
    public static let blockRemoteRules = """
    [{"trigger":{"url-filter":"^https?://.*"},"action":{"type":"block"}}]
    """
    static let openSchemes: Set<String> = ["http", "https", "mailto"]
    static var family: String {
        Design.Family.text.map { $0 == "system-ui" ? $0 : "'\($0)'" }.joined(separator: ",")
    }

    public static func inlineSource(_ reference: String, in images: [String: String]) -> MailInlineSource? {
        var key = reference.trimmingCharacters(in: .whitespaces)
        if key.lowercased().hasPrefix("cid:") { key = String(key.dropFirst(4)) }
        key = key.trimmingCharacters(in: CharacterSet(charactersIn: "<> "))
        guard let value = images[key] ?? key.removingPercentEncoding.flatMap({ images[$0] }), !value.isEmpty else { return nil }
        guard value.hasPrefix("data:") else { return .attachment(value) }
        guard let comma = value.firstIndex(of: ","),
              let data = Data(base64Encoded: String(value[value.index(after: comma)...])) else { return nil }
        let head = value[value.index(value.startIndex, offsetBy: 5)..<comma]
        let mime = head.split(separator: ";").first.map(String.init) ?? ""
        return .embedded(data, mime: mime.hasPrefix("image/") ? mime : mimeType(of: data))
    }

    public static func mimeType(of data: Data) -> String {
        let bytes = [UInt8](data.prefix(2))
        guard bytes.count == 2 else { return "application/octet-stream" }
        switch (bytes[0], bytes[1]) {
        case (0x89, 0x50): return "image/png"
        case (0xFF, 0xD8): return "image/jpeg"
        case (0x47, 0x49): return "image/gif"
        case (0x52, 0x49): return "image/webp"
        default: return "application/octet-stream"
        }
    }

    public static func navigation(scheme: String?, linkActivated: Bool, mainFrame: Bool) -> MailNavigation {
        let name = scheme?.lowercased() ?? ""
        if linkActivated { return openSchemes.contains(name) ? .open : .cancel }
        if mainFrame { return name.isEmpty || name == "about" ? .allow : .cancel }
        return .allow
    }

    public static func css(_ color: RGB) -> String {
        let parts = [color.red, color.green, color.blue].map { String(Int(($0 * 255).rounded())) }
        return "rgba(\(parts.joined(separator: ",")),\(color.alpha))"
    }

    public static func document(_ body: String, style: MailHTMLStyle) -> String {
        let head = """
        <!doctype html><html><head><meta charset="utf-8">
        <style>
        :root { color-scheme: light; }
        html, body { margin: 0; padding: 0; background: \(css(style.background)); overflow: hidden; }
        body { font: \(style.fontSize)px/\(style.lineHeight) \(family); color: \(css(style.text));
               overflow-wrap: anywhere; display: flow-root; -webkit-text-size-adjust: 100%; }
        img { max-width: 100%; height: auto; }
        table { max-width: 100%; }
        a { color: \(css(style.text)); }
        blockquote { margin: 0; padding-left: \(style.quoteGap)px; border-left: \(style.quoteBar)px solid \(css(style.line));
                     color: \(css(style.secondary)); }
        pre { white-space: pre-wrap; }
        </style></head><body>
        """
        return head + body + "</body></html>"
    }
}
