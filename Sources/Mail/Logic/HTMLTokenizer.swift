import Foundation

struct HTMLTokenizer {
    private static let rawTextTags: Set<String> = ["style", "script", "textarea", "title"]
    private static let lessThan = UInt8(ascii: "<")
    private static let greaterThan = UInt8(ascii: ">")
    private static let slash = UInt8(ascii: "/")
    private static let equals = UInt8(ascii: "=")
    private static let doubleQuote = UInt8(ascii: "\"")
    private static let singleQuote = UInt8(ascii: "'")
    private static let bang = UInt8(ascii: "!")
    private static let question = UInt8(ascii: "?")

    private let bytes: [UInt8]
    private var index = 0
    private var tokens: [HTMLToken] = []

    private init(bytes: [UInt8]) {
        self.bytes = bytes
    }

    static func tokens(_ html: String) -> [HTMLToken] {
        var scanner = HTMLTokenizer(bytes: Array(html.utf8))
        scanner.run()
        return scanner.tokens
    }

    private mutating func run() {
        var textStart = 0
        while index < bytes.count {
            guard bytes[index] == Self.lessThan, opensMarkup(at: index) else {
                index += 1
                continue
            }
            emitText(from: textStart, to: index)
            readMarkup()
            textStart = index
        }
        emitText(from: textStart, to: bytes.count)
    }

    private func opensMarkup(at position: Int) -> Bool {
        guard position + 1 < bytes.count else { return false }
        let next = bytes[position + 1]
        return Self.isLetter(next) || next == Self.slash && position + 2 < bytes.count && Self.isLetter(bytes[position + 2])
            || next == Self.bang || next == Self.question
    }

    private mutating func emitText(from start: Int, to end: Int) {
        guard end > start else { return }
        tokens.append(.text(String(decoding: bytes[start..<end], as: UTF8.self)))
    }

    private mutating func readMarkup() {
        let next = bytes[index + 1]
        if next == Self.bang || next == Self.question {
            skipDeclaration()
        } else if next == Self.slash {
            readEnd()
        } else {
            readStart()
        }
    }

    private mutating func skipDeclaration() {
        if matches("<!--", at: index) {
            index = find("-->", from: index + 4).map { $0 + 3 } ?? bytes.count
            return
        }
        index = (bytes[index...].firstIndex(of: Self.greaterThan)).map { $0 + 1 } ?? bytes.count
    }

    private mutating func readEnd() {
        let begin = index
        index += 2
        let nameStart = index
        while index < bytes.count, !Self.isSpace(bytes[index]), bytes[index] != Self.greaterThan, bytes[index] != Self.slash { index += 1 }
        let name = String(decoding: bytes[nameStart..<index], as: UTF8.self).lowercased()
        index = (bytes[index...].firstIndex(of: Self.greaterThan)).map { $0 + 1 } ?? bytes.count
        tokens.append(HTMLToken(kind: .end, name: name, attributes: [:], selfClosing: false,
                                raw: String(decoding: bytes[begin..<index], as: UTF8.self)))
    }

    private mutating func readStart() {
        let begin = index
        index += 1
        let nameStart = index
        while index < bytes.count, !Self.isSpace(bytes[index]), bytes[index] != Self.greaterThan, bytes[index] != Self.slash { index += 1 }
        let name = String(decoding: bytes[nameStart..<index], as: UTF8.self).lowercased()
        var attributes: [String: String] = [:]
        var selfClosing = false
        loop: while index < bytes.count {
            skipSpaces()
            guard index < bytes.count else { break }
            switch bytes[index] {
            case Self.greaterThan:
                index += 1
                break loop
            case Self.slash:
                selfClosing = true
                index += 1
            default:
                let attribute = readAttribute()
                if let attribute { attributes[attribute.name] = attribute.value }
                selfClosing = false
            }
        }
        tokens.append(HTMLToken(kind: .start, name: name, attributes: attributes, selfClosing: selfClosing,
                                raw: String(decoding: bytes[begin..<index], as: UTF8.self)))
        if Self.rawTextTags.contains(name), !selfClosing { readRawText(of: name) }
    }

    private mutating func readAttribute() -> (name: String, value: String)? {
        let nameStart = index
        while index < bytes.count, !Self.isSpace(bytes[index]), bytes[index] != Self.equals,
              bytes[index] != Self.greaterThan, bytes[index] != Self.slash { index += 1 }
        guard index > nameStart else {
            index += 1
            return nil
        }
        let name = String(decoding: bytes[nameStart..<index], as: UTF8.self).lowercased()
        skipSpaces()
        guard index < bytes.count, bytes[index] == Self.equals else { return (name, "") }
        index += 1
        skipSpaces()
        guard index < bytes.count else { return (name, "") }
        let quote = bytes[index]
        if quote == Self.doubleQuote || quote == Self.singleQuote {
            index += 1
            let valueStart = index
            while index < bytes.count, bytes[index] != quote { index += 1 }
            let value = String(decoding: bytes[valueStart..<index], as: UTF8.self)
            if index < bytes.count { index += 1 }
            return (name, value)
        }
        let valueStart = index
        while index < bytes.count, !Self.isSpace(bytes[index]), bytes[index] != Self.greaterThan { index += 1 }
        return (name, String(decoding: bytes[valueStart..<index], as: UTF8.self))
    }

    private mutating func readRawText(of name: String) {
        let start = index
        let close = find("</" + name, from: index, ignoringCase: true) ?? bytes.count
        if close > start { tokens.append(.text(String(decoding: bytes[start..<close], as: UTF8.self), kind: .raw)) }
        index = close
    }

    private mutating func skipSpaces() {
        while index < bytes.count, Self.isSpace(bytes[index]) { index += 1 }
    }

    private func matches(_ pattern: String, at position: Int) -> Bool {
        let needle = Array(pattern.utf8)
        guard position + needle.count <= bytes.count else { return false }
        return Array(bytes[position..<(position + needle.count)]) == needle
    }

    private func find(_ pattern: String, from start: Int, ignoringCase: Bool = false) -> Int? {
        let needle = Array((ignoringCase ? pattern.lowercased() : pattern).utf8)
        guard !needle.isEmpty, bytes.count >= needle.count, start <= bytes.count - needle.count else { return nil }
        var position = start
        while position <= bytes.count - needle.count {
            var hit = true
            for offset in 0..<needle.count {
                let byte = ignoringCase ? Self.lower(bytes[position + offset]) : bytes[position + offset]
                if byte != needle[offset] {
                    hit = false
                    break
                }
            }
            if hit { return position }
            position += 1
        }
        return nil
    }

    private static func isLetter(_ byte: UInt8) -> Bool {
        (byte >= 65 && byte <= 90) || (byte >= 97 && byte <= 122)
    }

    private static func isSpace(_ byte: UInt8) -> Bool {
        byte == 32 || byte == 9 || byte == 10 || byte == 13 || byte == 12
    }

    private static func lower(_ byte: UInt8) -> UInt8 {
        byte >= 65 && byte <= 90 ? byte + 32 : byte
    }
}

struct HTMLPlainWriter {
    private struct Link {
        var href: String
        var start: Int
    }

    private struct ListState {
        var ordered: Bool
        var count = 0
    }

    private static let skipped: Set<String> = ["head", "style", "script", "title", "template", "svg", "textarea"]
    private static let hiddenMarks = ["display:none", "mso-hide:all", "visibility:hidden"]
    private static let inlineMarks = ["display:inline"]
    private static let collapsedMarks = ["font-size:0;", "font-size:0px", "font-size:0pt", "font-size:0em"]
    private static let zeroWidth = CharacterSet(charactersIn: "\u{200B}\u{200C}\u{200D}\u{2060}\u{FEFF}\u{034F}\u{00AD}")
    private static let maxLinkLength = 150
    private static let breaks: [String: Int] = [
        "p": 2, "h1": 2, "h2": 2, "h3": 2, "h4": 2, "h5": 2, "h6": 2, "pre": 2, "ul": 2, "ol": 2, "dl": 2,
        "div": 1, "section": 1, "article": 1, "header": 1, "footer": 1, "main": 1, "nav": 1, "aside": 1,
        "address": 1, "figure": 1, "form": 1, "center": 1, "details": 1, "summary": 1, "dt": 1, "dd": 1,
        "table": 1, "tr": 1, "li": 1, "hr": 1, "caption": 1
    ]
    private static let bullet = "\u{2022} "
    private static let quoteMark = ">"

    private var out = ""
    private var owed = 0
    private var spaceOwed = false
    private var depth = 0
    private var breakDepth = 0
    private var marker: String?
    private var lists: [ListState] = []
    private var links: [Link] = []
    private var preformatted = 0
    private var hidden: (name: String, depth: Int)?
    private var collapsed: (name: String, depth: Int)?
    private var blocks: [(name: String, inline: Bool)] = []

    static func render(_ tokens: [HTMLToken]) -> String {
        var writer = HTMLPlainWriter()
        for token in tokens { writer.consume(token) }
        return writer.finish()
    }

    private mutating func consume(_ token: HTMLToken) {
        if hidden != nil {
            skip(token)
            return
        }
        trackCollapse(token)
        switch token.kind {
        case .text: write(HTMLEngine.decodeEntities(token.raw))
        case .raw: break
        case .start: open(token)
        case .end: close(token.name)
        }
    }

    private mutating func trackCollapse(_ token: HTMLToken) {
        guard !token.isVoid else { return }
        if let current = collapsed {
            guard token.name == current.name else { return }
            if token.kind == .start {
                collapsed?.depth += 1
            } else if token.kind == .end {
                collapsed?.depth -= 1
                if collapsed?.depth == 0 { collapsed = nil }
            }
        } else if token.kind == .start, Self.style(token, contains: Self.collapsedMarks) {
            collapsed = (token.name, 1)
        }
    }

    private static func style(_ token: HTMLToken, contains marks: [String]) -> Bool {
        guard let style = token.attributes["style"]?.lowercased().replacingOccurrences(of: " ", with: "") else { return false }
        let closed = style.hasSuffix(";") ? style : style + ";"
        return marks.contains { closed.contains($0) }
    }

    private mutating func skip(_ token: HTMLToken) {
        guard let current = hidden, token.name == current.name, !token.isVoid else { return }
        if token.kind == .start {
            hidden?.depth += 1
        } else if token.kind == .end {
            hidden?.depth -= 1
            if hidden?.depth == 0 { hidden = nil }
        }
    }

    private static func isHidden(_ token: HTMLToken) -> Bool {
        if token.attributes["hidden"] != nil { return true }
        guard let style = token.attributes["style"]?.lowercased().replacingOccurrences(of: " ", with: "") else { return false }
        return hiddenMarks.contains { style.contains($0) }
    }

    private static func isInline(_ token: HTMLToken) -> Bool {
        style(token, contains: inlineMarks)
    }

    private mutating func open(_ token: HTMLToken) {
        let name = token.name
        if Self.skipped.contains(name) || Self.isHidden(token) {
            if !token.isVoid { hidden = (name, 1) }
            return
        }
        switch name {
        case "br": owe(owed + 1)
        case "blockquote":
            depth += 1
            owe(1)
        case "ul", "ol":
            owe(lists.isEmpty ? 2 : 1)
            lists.append(ListState(ordered: name == "ol"))
        case "li":
            owe(1)
            item()
        case "pre":
            owe(2)
            preformatted += 1
        case "a":
            if let href = token.attributes["href"].map(HTMLEngine.decodeEntities), Self.worthShowing(href) {
                links.append(Link(href: href, start: out.utf8.count))
            } else {
                links.append(Link(href: "", start: out.utf8.count))
            }
        case "img":
            if let alt = token.attributes["alt"]?.trimmingCharacters(in: .whitespacesAndNewlines), !alt.isEmpty {
                write("[" + HTMLEngine.decodeEntities(alt) + "]")
            }
        case "td", "th":
            spaceOwed = true
        default:
            guard let count = Self.breaks[name] else { return }
            let inline = Self.isInline(token)
            blocks.append((name, inline))
            if !inline { owe(count) }
        }
    }

    private mutating func close(_ name: String) {
        switch name {
        case "blockquote":
            depth = max(0, depth - 1)
            owe(2)
        case "ul", "ol":
            if !lists.isEmpty { lists.removeLast() }
            owe(lists.isEmpty ? 2 : 1)
        case "pre":
            preformatted = max(0, preformatted - 1)
            owe(2)
        case "a":
            endLink()
        case "td", "th":
            spaceOwed = true
        default:
            guard let count = Self.breaks[name] else { return }
            let inline = blocks.lastIndex { $0.name == name }.map { blocks.remove(at: $0).inline } ?? false
            if !inline { owe(count) }
        }
    }

    private mutating func owe(_ count: Int) {
        breakDepth = owed == 0 ? depth : min(breakDepth, depth)
        owed = min(2, max(owed, count))
    }

    private mutating func item() {
        guard !lists.isEmpty else {
            marker = Self.bullet
            return
        }
        lists[lists.count - 1].count += 1
        let state = lists[lists.count - 1]
        let indent = String(repeating: "  ", count: lists.count - 1)
        marker = indent + (state.ordered ? "\(state.count). " : Self.bullet)
    }

    private mutating func endLink() {
        guard let link = links.popLast(), !link.href.isEmpty, out.utf8.count > link.start else { return }
        let shown = String(decoding: Array(out.utf8.dropFirst(link.start)), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !shown.isEmpty, !Self.same(shown, link.href) else { return }
        out += " (" + link.href + ")"
    }

    private static func worthShowing(_ href: String) -> Bool {
        let lower = href.lowercased()
        guard lower.hasPrefix("http://") || lower.hasPrefix("https://") || lower.hasPrefix("mailto:") else { return false }
        return href.count <= maxLinkLength
    }

    private static func same(_ text: String, _ href: String) -> Bool {
        func bare(_ value: String) -> String {
            var result = value.lowercased()
            for prefix in ["mailto:", "https://", "http://", "www."] where result.hasPrefix(prefix) {
                result.removeFirst(prefix.count)
            }
            while result.hasSuffix("/") { result.removeLast() }
            return result
        }
        let left = bare(text)
        let right = bare(href)
        return left == right || (href.lowercased().hasPrefix("mailto:") && text.lowercased().contains(right))
    }

    private var prefix: String {
        depth == 0 ? "" : String(repeating: Self.quoteMark + " ", count: depth)
    }

    private var blankPrefix: String {
        depth == 0 ? "" : String(repeating: Self.quoteMark, count: depth)
    }

    private var breakPrefix: String {
        breakDepth == 0 ? "" : String(repeating: Self.quoteMark, count: breakDepth)
    }

    private mutating func write(_ decoded: String) {
        let text = String(String.UnicodeScalarView(decoded.unicodeScalars.filter { !Self.zeroWidth.contains($0) }))
        if preformatted > 0 {
            writePreformatted(text)
            return
        }
        let core = text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        guard !core.isEmpty else {
            if !text.isEmpty, collapsed == nil { spaceOwed = true }
            return
        }
        if text.first?.isWhitespace == true { spaceOwed = true }
        begin()
        out += core
        spaceOwed = text.last?.isWhitespace == true
    }

    private mutating func writePreformatted(_ text: String) {
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        for (position, line) in lines.enumerated() {
            if position == 0 {
                if !line.isEmpty {
                    begin()
                    out += line
                }
            } else {
                out += "\n" + (line.isEmpty ? blankPrefix : prefix) + line
                owed = 0
                spaceOwed = false
            }
        }
    }

    private mutating func begin() {
        if out.isEmpty {
            out += prefix
        } else if owed > 0 {
            for step in 1...owed { out += "\n" + (step < owed ? breakPrefix : prefix) }
            spaceOwed = false
        } else if spaceOwed {
            out += " "
        }
        owed = 0
        spaceOwed = false
        if let marker {
            out += marker
            self.marker = nil
        }
    }

    private func finish() -> String {
        var result = out
        result = result.replacingOccurrences(of: "[ \\t]+\\n", with: "\n", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum FlowedEngine {
    public static func text(_ data: Data, contentType: String?) -> String {
        let type = RawMessageEngine.parameters(contentType ?? "")
        let text = MIME.string(from: data, charset: type.parameters["charset"])
        guard type.value == "text/plain", type.parameters["format"]?.lowercased() == "flowed" else { return text }
        return MIME.unflow(text, delSp: type.parameters["delsp"]?.lowercased() == "yes")
    }
}

enum PreviewEngine {
    private static let lineBreaks = try? NSRegularExpression(pattern: #"\s+(?=(?:Am|On)\s)|(?<=:)\s*(?=[>›])"#)
    private static let quoteRuns = try? NSRegularExpression(pattern: #"(>\s*)+"#)
    private static let dividers = ["-----original", "-----ursprüngliche", "________________________________"]
    private static let sendLines = ["sent from my", "gesendet von meinem"]

    static func text(_ raw: String) -> String {
        var kept: [String] = []
        for line in raw.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lower = trimmed.lowercased()
            if trimmed == "--" || trimmed == "\u{2014}" || dividers.contains(where: lower.hasPrefix) || sendLines.contains(where: lower.hasPrefix) { break }
            kept.append(trimmed)
        }
        var flat = ownText(broken(kept.joined(separator: "\n")))
        if let regex = quoteRuns {
            flat = regex.stringByReplacingMatches(in: flat, range: NSRange(flat.startIndex..., in: flat), withTemplate: " ")
        }
        let words = flat.split(whereSeparator: { $0.isWhitespace })
        var result = words.joined(separator: " ")
        while let last = result.last, "\u{2014}\u{2013}-".contains(last) { result.removeLast() }
        return result.trimmingCharacters(in: .whitespaces)
    }

    static func draft(_ raw: String, signature: String?) -> String {
        let plain = text(raw)
        guard let signature else { return plain }
        let own = plain.split(separator: " ").map(String.init)
        let sign = signature.split(whereSeparator: { $0.isWhitespace }).map(String.init).filter { $0 != "--" }
        guard !own.isEmpty, !sign.isEmpty else { return plain }
        if own.count >= sign.count {
            for start in stride(from: own.count - sign.count, through: 0, by: -1) where Array(own[start..<start + sign.count]) == sign {
                return (own[..<start] + own[(start + sign.count)...]).joined(separator: " ")
            }
        }
        for start in own.indices where own.count - start < sign.count {
            let tail = Array(own[start...])
            if (start == 0 || tail.count >= 2) && tail == Array(sign[..<tail.count]) {
                return own[..<start].joined(separator: " ")
            }
        }
        return plain
    }

    private static func broken(_ text: String) -> String {
        guard let regex = lineBreaks else { return text }
        return regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "\n")
    }

    private static func ownText(_ text: String) -> String {
        var rest = text
        var own: [String] = []
        while true {
            let parts = Quoting.split(rest)
            own.append(parts.body)
            guard let quote = parts.quote else { break }
            rest = after(quote.text)
        }
        return own.joined(separator: " ")
    }

    private static func after(_ quote: String) -> String {
        let lines = quote.components(separatedBy: "\n").dropFirst()
        let tail = lines.drop { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty || trimmed.hasPrefix(">") || trimmed.hasPrefix("\u{203A}")
        }
        return tail.joined(separator: "\n")
    }
}
