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
