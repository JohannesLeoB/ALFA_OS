import Foundation

enum RawMessageEngine {
    struct Parsed: Equatable {
        var headers: [HeaderField]
        var root: IMAPBodyPart
        var bodies: [String: Data]

        func header(_ name: String) -> String? {
            headers.first { $0.name.lowercased() == name.lowercased() }?.value
        }

        func text(_ part: IMAPBodyPart) -> String {
            let decoded = MIME.decodeTransfer(bodies[part.section] ?? Data(), encoding: part.encoding)
            let text = MIME.string(from: decoded, charset: part.charset)
            return part.isFlowed ? MIME.unflow(text, delSp: part.deletesSpaces) : text
        }

        func data(_ part: IMAPBodyPart) -> Data {
            MIME.decodeTransfer(bodies[part.section] ?? Data(), encoding: part.encoding)
        }

        var html: String? {
            root.firstHTML.map(text)
        }

        var preview: String {
            let plain = root.firstPlainText.map { PreviewEngine.text(text($0)) } ?? ""
            guard plain.isEmpty, let html else { return plain }
            return PreviewEngine.text(HTMLEngine.plain(html))
        }

        var attachments: [AttachmentInfo] {
            root.attachments(html: html, embedded: root.inlineContentIDs).map {
                AttachmentInfo(id: $0.section, filename: $0.filename ?? $0.section, mimeType: $0.mimeType, sizeBytes: $0.size)
            }
        }
    }

    private static let depthLimit = 12

    static func parse(_ data: Data) -> Parsed {
        let bytes = [UInt8](data)
        var bodies: [String: Data] = [:]
        let (headers, start) = split(bytes, from: 0, to: bytes.count)
        let root = part(headers, bytes, start, bytes.count, section: "", depth: 0, bodies: &bodies)
        return Parsed(headers: MIME.parseHeaders(Data(bytes[0..<start])).map(decoded), root: root, bodies: bodies)
    }

    static func body(_ parsed: Parsed) -> MessageBody {
        var body = MessageBody()
        if let part = parsed.root.firstPlainText { body.text = parsed.text(part) }
        body.html = parsed.html
        for part in parsed.root.inlineImages {
            guard let contentID = part.contentID, !contentID.isEmpty else { continue }
            body.inlineImages[contentID] = "data:\(part.mimeType);base64,\(parsed.data(part).base64EncodedString())"
        }
        body.attachments = parsed.attachments
        body.unsubscribe = UnsubscribeEngine.parse(parsed.headers)
        return body
    }

    static func summary(_ parsed: Parsed, id: String, folder: String, flags: Set<Flag>, received: Date?) -> MessageSummary {
        let from = parsed.header("From") ?? parsed.header("Sender") ?? ""
        let messageID = parsed.header("Message-ID") ?? ""
        let reference = parsed.header("References")?.split(separator: " ").first.map(String.init)
        let thread = reference ?? parsed.header("In-Reply-To") ?? (messageID.isEmpty ? id : messageID)
        let attachments = parsed.attachments
        return MessageSummary(
            id: id, threadID: thread, subject: parsed.header("Subject") ?? "", from: display(from),
            fromRaw: from, toRaw: parsed.header("To") ?? "", ccRaw: parsed.header("Cc") ?? "",
            bccRaw: parsed.header("Bcc") ?? "",
            replyToRaw: parsed.header("Reply-To") ?? "", snippet: parsed.preview,
            receivedAt: received ?? parsed.header("Date").flatMap(DateEngine.parseMessageDate), flags: flags,
            folderIDs: [folder], attachmentCount: attachments.count, attachments: attachments, messageIDHeader: messageID)
    }

    static func display(_ list: String) -> String {
        guard let first = AddressListParser.split(list).first else { return "" }
        let address = AddressEngine.email(first)
        guard let open = first.lastIndex(of: "<") else { return address }
        let name = first[first.startIndex..<open].trimmingCharacters(in: CharacterSet(charactersIn: " \""))
        return name.isEmpty ? address : name
    }

    static func parameters(_ value: String) -> (value: String, parameters: [String: String]) {
        var pieces: [String] = []
        var current = ""
        var quoted = false
        var escaped = false
        for character in value {
            if escaped {
                current.append(character)
                escaped = false
            } else if character == "\\" && quoted {
                escaped = true
            } else if character == "\"" {
                quoted.toggle()
            } else if character == ";" && !quoted {
                pieces.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        pieces.append(current)
        let main = pieces.first?.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
        let pairs: [(String, String)] = pieces.dropFirst().compactMap { piece in
            guard let equal = piece.firstIndex(of: "=") else { return nil }
            let key = piece[piece.startIndex..<equal].trimmingCharacters(in: .whitespaces).lowercased()
            let raw = piece[piece.index(after: equal)...].trimmingCharacters(in: .whitespaces)
            return key.isEmpty ? nil : (key, raw)
        }
        return (main, MIME.resolveExtended(pairs))
    }

    private static func decoded(_ field: HeaderField) -> HeaderField {
        let name = field.name.lowercased()
        guard !["from", "to", "cc", "bcc", "reply-to", "sender"].contains(name) else {
            let entries = AddressListParser.split(field.value).map(MIME.decodeEncodedWords)
            return HeaderField(name: field.name, value: entries.joined(separator: ", "))
        }
        return HeaderField(name: field.name, value: MIME.decodeEncodedWords(field.value))
    }

    private static func split(_ bytes: [UInt8], from: Int, to end: Int) -> ([HeaderField], Int) {
        var index = from
        var lineStart = from
        while index < end {
            if bytes[index] == 10 {
                let line = bytes[lineStart..<index]
                if line.isEmpty || line == [13] {
                    return (MIME.parseHeaders(Data(bytes[from..<index])), index + 1)
                }
                lineStart = index + 1
            }
            index += 1
        }
        return (MIME.parseHeaders(Data(bytes[from..<end])), end)
    }

    private static func part(_ headers: [HeaderField], _ bytes: [UInt8], _ start: Int, _ end: Int, section: String,
                             depth: Int, bodies: inout [String: Data]) -> IMAPBodyPart {
        func value(_ name: String) -> String? { headers.first { $0.name.lowercased() == name }?.value }
        let type = parameters(value("content-type") ?? "text/plain; charset=us-ascii")
        let pieces = type.value.split(separator: "/", maxSplits: 1).map(String.init)
        var media = pieces.first ?? "text"
        var subtype = pieces.count > 1 ? pieces[1] : "plain"
        if media.isEmpty || subtype.isEmpty { (media, subtype) = ("text", "plain") }
        let disposition = value("content-disposition").map(parameters)
        let contentID = value("content-id").map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "<> ")) }
        var node = IMAPBodyPart(
            section: section.isEmpty ? "1" : section, mediaType: media, subtype: subtype, parameters: type.parameters,
            contentID: contentID, encoding: (value("content-transfer-encoding") ?? "7bit").lowercased(),
            size: max(0, end - start), disposition: disposition?.value, dispositionParameters: disposition?.parameters ?? [:],
            children: [])
        guard media == "multipart", let boundary = type.parameters["boundary"], !boundary.isEmpty, depth < depthLimit else {
            bodies[node.section] = Data(bytes[start..<end])
            return node
        }
        for (offset, range) in parts(bytes, start, end, boundary: boundary).enumerated() {
            let child = (section.isEmpty ? "" : section + ".") + String(offset + 1)
            let (childHeaders, bodyStart) = split(bytes, from: range.lowerBound, to: range.upperBound)
            node.children.append(part(childHeaders, bytes, bodyStart, range.upperBound, section: child, depth: depth + 1,
                                      bodies: &bodies))
        }
        node.section = section
        return node
    }

    private static func parts(_ bytes: [UInt8], _ start: Int, _ end: Int, boundary: String) -> [Range<Int>] {
        let marker = Array(("--" + boundary).utf8)
        var ranges: [Range<Int>] = []
        var open: Int?
        var lineStart = start
        while lineStart < end {
            var lineEnd = lineStart
            while lineEnd < end, bytes[lineEnd] != 10 { lineEnd += 1 }
            var content = lineEnd
            while content > lineStart, bytes[content - 1] == 13 || bytes[content - 1] == 32 || bytes[content - 1] == 9 {
                content -= 1
            }
            let line = Array(bytes[lineStart..<content])
            if line.count >= marker.count, Array(line[0..<marker.count]) == marker {
                let rest = line[marker.count...]
                if rest.isEmpty || Array(rest) == [45, 45] {
                    if let begin = open {
                        var stop = lineStart
                        if stop > begin, bytes[stop - 1] == 10 { stop -= 1 }
                        if stop > begin, bytes[stop - 1] == 13 { stop -= 1 }
                        ranges.append(begin..<max(begin, stop))
                    }
                    if !rest.isEmpty { return ranges }
                    open = min(lineEnd + 1, end)
                }
            }
            lineStart = lineEnd + 1
        }
        if let begin = open, begin < end { ranges.append(begin..<end) }
        return ranges
    }
}

enum MIME {
    private static let base64Alphabet = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".utf8)
    private static let encodedWord = try? NSRegularExpression(pattern: "=\\?([^?\\s]+)\\?([BbQq])\\?([^?\\s]*)\\?=")

    static func decodeBase64(_ data: Data) -> Data {
        var filtered = data.filter { base64Alphabet.contains($0) }
        if filtered.count % 4 == 1 { filtered.removeLast() }
        while filtered.count % 4 != 0 { filtered.append(61) }
        return Data(base64Encoded: filtered) ?? Data()
    }

    static func decodeQuotedPrintable(_ data: Data, header: Bool = false) -> Data {
        let bytes = [UInt8](data)
        var out = [UInt8]()
        out.reserveCapacity(bytes.count)
        var index = 0
        while index < bytes.count {
            let byte = bytes[index]
            if byte == 61 {
                if index + 1 < bytes.count, bytes[index + 1] == 10 {
                    index += 2
                    continue
                }
                if index + 2 < bytes.count, bytes[index + 1] == 13, bytes[index + 2] == 10 {
                    index += 3
                    continue
                }
                if index + 2 < bytes.count, let high = hexValue(bytes[index + 1]), let low = hexValue(bytes[index + 2]) {
                    out.append(UInt8(high * 16 + low))
                    index += 3
                    continue
                }
                out.append(byte)
                index += 1
            } else if header && byte == 95 {
                out.append(32)
                index += 1
            } else {
                out.append(byte)
                index += 1
            }
        }
        return Data(out)
    }

    private static func hexValue(_ byte: UInt8) -> Int? {
        switch byte {
        case 48...57: Int(byte) - 48
        case 65...70: Int(byte) - 55
        case 97...102: Int(byte) - 87
        default: nil
        }
    }

    static func decodeTransfer(_ data: Data, encoding: String) -> Data {
        switch encoding.lowercased() {
        case "base64": decodeBase64(data)
        case "quoted-printable": decodeQuotedPrintable(data)
        default: data
        }
    }

    static func string(from data: Data, charset: String?) -> String {
        if let name = charset?.trimmingCharacters(in: CharacterSet(charactersIn: "\" ")), !name.isEmpty {
            let base = name.split(separator: "*", maxSplits: 1).first.map(String.init) ?? name
            let converted = CFStringConvertIANACharSetNameToEncoding(base as CFString)
            if converted != kCFStringEncodingInvalidId {
                let encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(converted))
                if let text = String(data: data, encoding: encoding) { return text }
            }
        }
        return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
    }

    static func truncatedString(from data: Data, charset: String?) -> String {
        let bytes = [UInt8](data)
        guard charset.map({ $0.lowercased().contains("utf") }) ?? true else { return string(from: data, charset: charset) }
        for back in 1...3 where bytes.count >= back {
            let lead = bytes[bytes.count - back]
            if lead < 0x80 { break }
            if lead < 0xC0 { continue }
            let needed = lead >= 0xF0 ? 4 : lead >= 0xE0 ? 3 : 2
            if needed > back, String(data: data, encoding: .utf8) == nil {
                return string(from: Data(bytes.dropLast(back)), charset: charset)
            }
            break
        }
        return string(from: data, charset: charset)
    }

    static func unflow(_ text: String, delSp: Bool) -> String {
        var out: [String] = []
        var pending: (depth: Int, text: String)?
        func flush() {
            guard let held = pending else { return }
            let prefix = held.depth == 0 ? "" : String(repeating: ">", count: held.depth) + (held.text.isEmpty ? "" : " ")
            out.append(prefix + held.text)
            pending = nil
        }
        for raw in text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n") {
            var line = Substring(raw)
            var depth = 0
            while line.first == ">" {
                depth += 1
                line = line.dropFirst()
            }
            if line.first == " " { line = line.dropFirst() }
            let flowed = line.hasSuffix(" ") && line != "-- "
            let piece = flowed && delSp ? String(line.dropLast()) : String(line)
            if let held = pending, held.depth == depth {
                pending = (depth, held.text + piece)
            } else {
                flush()
                pending = (depth, piece)
            }
            if !flowed { flush() }
        }
        flush()
        return out.joined(separator: "\n")
    }

    static func decodeEncodedWords(_ text: String) -> String {
        guard text.contains("=?"), let regex = encodedWord else { return text }
        let source = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: source.length))
        guard !matches.isEmpty else { return text }
        var result = ""
        var cursor = 0
        var previousWasWord = false
        for match in matches {
            let gap = source.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            let gapIsBlank = gap.allSatisfy(\.isWhitespace)
            if !(previousWasWord && gapIsBlank) { result += gap }
            let charset = source.substring(with: match.range(at: 1))
            let kind = source.substring(with: match.range(at: 2)).uppercased()
            let payload = Data(source.substring(with: match.range(at: 3)).utf8)
            let raw = kind == "B" ? decodeBase64(payload) : decodeQuotedPrintable(payload, header: true)
            result += string(from: raw, charset: charset)
            cursor = match.range.location + match.range.length
            previousWasWord = true
        }
        result += source.substring(from: cursor)
        return result
    }

    static func parseHeaders(_ data: Data) -> [HeaderField] {
        let text = string(from: data, charset: nil)
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        var fields: [HeaderField] = []
        for line in normalized.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.isEmpty { break }
            if line.first == " " || line.first == "\t", !fields.isEmpty {
                fields[fields.count - 1].value += " " + line.trimmingCharacters(in: .whitespaces)
            } else if let colon = line.firstIndex(of: ":") {
                let name = String(line[line.startIndex..<colon]).trimmingCharacters(in: .whitespaces)
                let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                fields.append(HeaderField(name: name, value: value))
            }
        }
        return fields
    }

    static func resolveExtended(_ pairs: [(String, String)]) -> [String: String] {
        var plain: [String: String] = [:]
        var segments: [String: [(Int, String, Bool)]] = [:]
        for (key, value) in pairs {
            guard let star = key.firstIndex(of: "*") else {
                plain[key] = decodeEncodedWords(value)
                continue
            }
            let base = String(key[key.startIndex..<star])
            let suffix = String(key[key.index(after: star)...])
            if suffix.isEmpty {
                segments[base, default: []].append((0, value, true))
            } else if suffix.hasSuffix("*"), let number = Int(suffix.dropLast()) {
                segments[base, default: []].append((number, value, true))
            } else if let number = Int(suffix) {
                segments[base, default: []].append((number, value, false))
            }
        }
        for (base, list) in segments {
            let ordered = list.sorted { $0.0 < $1.0 }
            var charset: String?
            var joined = Data()
            for (offset, entry) in ordered.enumerated() {
                var piece = entry.1
                if entry.2 {
                    if offset == 0 {
                        let sections = piece.split(separator: "'", maxSplits: 2, omittingEmptySubsequences: false)
                        if sections.count == 3 {
                            charset = String(sections[0])
                            piece = String(sections[2])
                        }
                    }
                    joined.append(percentDecode(piece))
                } else {
                    joined.append(Data(piece.utf8))
                }
            }
            plain[base] = string(from: joined, charset: charset)
        }
        return plain
    }

    private static func percentDecode(_ text: String) -> Data {
        let bytes = [UInt8](text.utf8)
        var out = [UInt8]()
        var index = 0
        while index < bytes.count {
            if bytes[index] == 37, index + 2 < bytes.count,
               let high = hexValue(bytes[index + 1]), let low = hexValue(bytes[index + 2]) {
                out.append(UInt8(high * 16 + low))
                index += 3
            } else {
                out.append(bytes[index])
                index += 1
            }
        }
        return Data(out)
    }
}

public struct ListUnsubscribe: Codable, Equatable, Sendable {
    public var mail: URL?
    public var web: URL?
    public var oneClick: Bool

    public var unsubscribes: Bool { oneClick || mail != nil }
}

public enum UnsubscribeEngine {
    static let headerName = "List-Unsubscribe"
    static let postName = "List-Unsubscribe-Post"
    static let oneClickBody = "List-Unsubscribe=One-Click"
    static let fallbackSubject = "unsubscribe"

    public static func parse(_ header: String?, post: String?) -> ListUnsubscribe? {
        guard let header else { return nil }
        var mail: URL?
        var web: URL?
        for link in links(header) {
            guard let url = URL(string: link), let scheme = url.scheme?.lowercased() else { continue }
            if scheme == "mailto", mail == nil, draft(url) != nil { mail = url }
            if scheme == "https" || scheme == "http", web == nil { web = url }
        }
        guard mail != nil || web != nil else { return nil }
        let asked = (post ?? "").filter { !$0.isWhitespace }.lowercased() == oneClickBody.lowercased()
        return ListUnsubscribe(mail: mail, web: web, oneClick: asked && web?.scheme?.lowercased() == "https")
    }

    static func parse(_ headers: [HeaderField]) -> ListUnsubscribe? {
        func value(_ name: String) -> String? { headers.first { $0.name.lowercased() == name.lowercased() }?.value }
        return parse(value(headerName), post: value(postName))
    }

    static func links(_ header: String) -> [String] {
        var result: [String] = []
        var rest = Substring(header)
        while let open = rest.firstIndex(of: "<"), let close = rest[open...].firstIndex(of: ">") {
            result.append(String(rest[rest.index(after: open)..<close].filter { !$0.isWhitespace }))
            rest = rest[rest.index(after: close)...]
        }
        return result
    }

    public static func draft(_ url: URL) -> Draft? {
        guard url.scheme?.lowercased() == "mailto",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let address = components.path.removingPercentEncoding ?? components.path
        guard AddressListParser.split(address).count == 1 else { return nil }
        let items = components.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name.lowercased() == name }?.value }
        let subject = value("subject").flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 } ?? fallbackSubject
        return Draft(to: address, subject: subject, body: value("body") ?? "")
    }

    static func request(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(oneClickBody.utf8)
        return request
    }
}
