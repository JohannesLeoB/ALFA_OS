import Design
import Foundation

public enum Navigation: Equatable, Sendable {
    case allow
    case open
    case compose
    case cancel
}

public struct MailtoTarget: Equatable, Sendable {
    public let to: String
    public let cc: String
    public let subject: String
    public let body: String
}

public enum HTMLEngine {
    public static let ruleListID = "alfa.mail.block-remote"
    public static let inlineScheme = "cid"
    public static let blockRemoteRules = """
    [{"trigger":{"url-filter":"^https?://.*"},"action":{"type":"block"}}]
    """
    public static let measureScript = """
    (function(){var b=document.body,d=document.documentElement;b.style.transform='';b.style.width='';\
    var w=d.clientWidth,s=Math.max(b.scrollWidth,d.scrollWidth);\
    if(s>w+1){b.style.transformOrigin='0 0';b.style.width=s+'px';b.style.transform='scale('+(w/s)+')'}\
    return Math.ceil(b.getBoundingClientRect().height)})()
    """
    private static let openSchemes: Set<String> = ["http", "https"]
    private static let mailScheme = "mailto"
    private static let maxEntityLength = 10
    private static let namedEntities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ", "zwnj": "", "zwj": "", "shy": "",
        "auml": "\u{E4}", "ouml": "\u{F6}", "uuml": "\u{FC}", "Auml": "\u{C4}", "Ouml": "\u{D6}", "Uuml": "\u{DC}",
        "szlig": "\u{DF}", "euro": "\u{20AC}", "ndash": "\u{2013}", "mdash": "\u{2014}", "hellip": "\u{2026}",
        "laquo": "\u{AB}", "raquo": "\u{BB}", "bdquo": "\u{201E}", "ldquo": "\u{201C}", "rdquo": "\u{201D}",
        "lsquo": "\u{2018}", "rsquo": "\u{2019}", "copy": "\u{A9}", "reg": "\u{AE}",
        "agrave": "\u{E0}", "aacute": "\u{E1}", "acirc": "\u{E2}", "egrave": "\u{E8}", "eacute": "\u{E9}",
        "ecirc": "\u{EA}", "iacute": "\u{ED}", "oacute": "\u{F3}", "ocirc": "\u{F4}", "uacute": "\u{FA}",
        "ccedil": "\u{E7}", "ntilde": "\u{F1}", "bull": "\u{2022}", "middot": "\u{B7}", "trade": "\u{2122}",
        "deg": "\u{B0}", "times": "\u{D7}", "sect": "\u{A7}", "para": "\u{B6}", "plusmn": "\u{B1}",
        "pound": "\u{A3}", "yen": "\u{A5}", "cent": "\u{A2}"
    ]

    private static var family: String {
        Tokens.Family.text.map { $0 == "system-ui" ? $0 : "'\($0)'" }.joined(separator: ",")
    }

    public static func plain(_ html: String) -> String {
        HTMLPlainWriter.render(HTMLTokenizer.tokens(html))
    }

    static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = ""
        var rest = Substring(text)
        while let amp = rest.firstIndex(of: "&") {
            result += rest[..<amp]
            let after = rest[rest.index(after: amp)...]
            if let semi = after.firstIndex(of: ";"), after.distance(from: after.startIndex, to: semi) <= maxEntityLength {
                let name = String(after[..<semi])
                if let value = entity(name) {
                    result += value
                    rest = after[after.index(after: semi)...]
                    continue
                }
            }
            result += "&"
            rest = after
        }
        return result + rest
    }

    static func entity(_ name: String) -> String? {
        if name.hasPrefix("#x") || name.hasPrefix("#X") {
            return UInt32(name.dropFirst(2), radix: 16).flatMap(Unicode.Scalar.init).map { String(Character($0)) }
        }
        if name.hasPrefix("#") {
            return UInt32(name.dropFirst()).flatMap(Unicode.Scalar.init).map { String(Character($0)) }
        }
        return namedEntities[name]
    }

    public static func inlineSource(_ reference: String, in images: [String: String]) -> InlineSource? {
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

    public static func navigation(scheme: String?, linkActivated: Bool, mainFrame: Bool) -> Navigation {
        let name = scheme?.lowercased() ?? ""
        if linkActivated {
            if name == mailScheme { return .compose }
            return openSchemes.contains(name) ? .open : .cancel
        }
        if mainFrame { return name.isEmpty || name == "about" ? .allow : .cancel }
        return .allow
    }

    public static func mailto(_ reference: String) -> MailtoTarget? {
        guard reference.lowercased().hasPrefix(mailScheme + ":") else { return nil }
        let rest = reference.dropFirst(mailScheme.count + 1)
        let halves = rest.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        var fields: [String: String] = [:]
        for pair in (halves.count > 1 ? halves[1] : "").split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard kv.count == 2 else { continue }
            fields[kv[0].lowercased()] = String(kv[1]).removingPercentEncoding ?? String(kv[1])
        }
        let first = halves.first.map(String.init) ?? ""
        let direct = first.removingPercentEncoding ?? first
        let to = [direct, fields["to"] ?? ""].filter { !$0.isEmpty }.joined(separator: ", ")
        return MailtoTarget(to: to, cc: fields["cc"] ?? "", subject: fields["subject"] ?? "", body: fields["body"] ?? "")
    }

    static func css(_ color: ColorValue) -> String {
        let parts = [color.red, color.green, color.blue].map { String(Int(($0 * 255).rounded())) }
        return "rgba(\(parts.joined(separator: ",")),\(color.alpha))"
    }

    public static func document(_ body: String, theme: HTMLTheme) -> String {
        let head = """
        <!doctype html><html><head><meta charset="utf-8">
        <style>
        :root { color-scheme: light; }
        html, body { margin: 0; padding: 0; background: \(css(theme.background)); overflow: hidden; }
        html, body { height: auto !important; min-height: 0 !important; }
        body { font: \(theme.fontSize)px/\(theme.lineHeight) \(family); color: \(css(theme.text));
               overflow-wrap: break-word; display: flow-root; -webkit-text-size-adjust: 100%; }
        img { max-width: 100%; height: auto; }
        table { max-width: 100%; }
        a { color: \(css(theme.text)); text-decoration: underline; }
        blockquote { margin: 0; padding-left: \(theme.quoteGap)px; border-left: \(theme.quoteBar)px solid \(css(theme.line));
                     color: \(css(theme.secondary)); }
        pre { white-space: pre-wrap; }
        </style></head><body>
        """
        return head + body + "</body></html>"
    }
}

public struct HTMLTheme: Equatable, Sendable {
    let text: ColorValue
    let secondary: ColorValue
    let line: ColorValue
    let background: ColorValue
    let fontSize: Double
    let lineHeight: Double
    let quoteBar: Double
    let quoteGap: Double

    public init(text: ColorValue, secondary: ColorValue, line: ColorValue, background: ColorValue, fontSize: Double,
                lineHeight: Double, quoteBar: Double, quoteGap: Double) {
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

public enum InlineSource: Equatable, Sendable {
    case embedded(Data, mime: String)
    case attachment(String)
}
