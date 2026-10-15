import Foundation

struct IMAPAddress: Equatable, Sendable {
    var name: String?
    var mailbox: String
    var host: String

    var address: String { "\(mailbox)@\(host)" }

    var display: String {
        let decoded = name.map(MailMIME.decodeEncodedWords)?.trimmingCharacters(in: .whitespaces) ?? ""
        return decoded.isEmpty ? address : decoded
    }

    var raw: String {
        let decoded = name.map(MailMIME.decodeEncodedWords)?.trimmingCharacters(in: .whitespaces) ?? ""
        guard decoded.isEmpty == false else { return address }
        let specials = CharacterSet(charactersIn: "()<>[]:;@\\,.\"")
        let needsQuotes = decoded.unicodeScalars.contains { specials.contains($0) }
        let shown = needsQuotes
            ? "\"" + decoded.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
            : decoded
        return "\(shown) <\(address)>"
    }
}

struct IMAPEnvelope: Equatable, Sendable {
    var date: String?
    var subject: String?
    var from: [IMAPAddress]
    var sender: [IMAPAddress]
    var replyTo: [IMAPAddress]
    var to: [IMAPAddress]
    var cc: [IMAPAddress]
    var bcc: [IMAPAddress]
    var inReplyTo: String?
    var messageID: String?

    static func parse(_ value: IMAPValue) -> IMAPEnvelope? {
        guard let items = value.items, items.count >= 10 else { return nil }
        return IMAPEnvelope(
            date: items[0].string,
            subject: items[1].string.map(MailMIME.decodeEncodedWords),
            from: addresses(items[2]), sender: addresses(items[3]), replyTo: addresses(items[4]),
            to: addresses(items[5]), cc: addresses(items[6]), bcc: addresses(items[7]),
            inReplyTo: items[8].string, messageID: items[9].string)
    }

    static func addresses(_ value: IMAPValue) -> [IMAPAddress] {
        guard let entries = value.items else { return [] }
        return entries.compactMap { entry in
            guard let fields = entry.items, fields.count >= 4,
                  let mailbox = fields[2].string, let host = fields[3].string else { return nil }
            return IMAPAddress(name: fields[0].string, mailbox: mailbox, host: host)
        }
    }
}

struct IMAPBodyPart: Equatable, Sendable {
    var section: String
    var mediaType: String
    var subtype: String
    var parameters: [String: String]
    var contentID: String?
    var encoding: String
    var size: Int
    var disposition: String?
    var dispositionParameters: [String: String]
    var children: [IMAPBodyPart]

    var isMultipart: Bool { mediaType == "multipart" }
    var mimeType: String { "\(mediaType)/\(subtype)" }
    var filename: String? { dispositionParameters["filename"] ?? parameters["name"] }
    var charset: String? { parameters["charset"] }

    var isAttachment: Bool {
        guard isMultipart == false else { return false }
        if disposition == "attachment" { return true }
        return filename != nil && disposition != "inline"
    }

    var leaves: [IMAPBodyPart] {
        if isMultipart { return children.flatMap(\.leaves) }
        return [self]
    }

    var attachments: [IMAPBodyPart] { leaves.filter(\.isAttachment) }

    var firstPlainText: IMAPBodyPart? {
        leaves.first { $0.mimeType == "text/plain" && $0.isAttachment == false }
    }

    var firstHTML: IMAPBodyPart? {
        leaves.first { $0.mimeType == "text/html" && $0.isAttachment == false }
    }

    var inlineImages: [IMAPBodyPart] {
        leaves.filter { $0.mediaType == "image" && $0.contentID != nil }
    }
}

enum IMAPBodyStructureParser {
    static func parse(_ value: IMAPValue) throws -> IMAPBodyPart {
        guard let items = value.items else { throw MailTransportError.malformedResponse("bodystructure") }
        return try node(items, section: items.first?.items != nil ? "" : "1")
    }

    private static func node(_ items: [IMAPValue], section: String) throws -> IMAPBodyPart {
        if items.first?.items != nil {
            var children: [IMAPBodyPart] = []
            var position = 0
            while position < items.count, let child = items[position].items {
                let childSection = section.isEmpty ? String(position + 1) : "\(section).\(position + 1)"
                children.append(try node(child, section: childSection))
                position += 1
            }
            let subtype = position < items.count ? (items[position].string ?? "").lowercased() : ""
            let parameters = position + 1 < items.count ? pairs(items[position + 1]) : [:]
            let dispositionIndex = position + 2
            let (disposition, dispositionParameters) = dispositionFields(items, at: dispositionIndex)
            return IMAPBodyPart(
                section: section, mediaType: "multipart", subtype: subtype, parameters: parameters, contentID: nil,
                encoding: "7bit", size: 0, disposition: disposition, dispositionParameters: dispositionParameters,
                children: children)
        }
        guard items.count >= 7 else { throw MailTransportError.malformedResponse("bodystructurePart") }
        let mediaType = (items[0].string ?? "").lowercased()
        let subtype = (items[1].string ?? "").lowercased()
        var position = 7
        var children: [IMAPBodyPart] = []
        if mediaType == "text" {
            position += 1
        } else if mediaType == "message", subtype == "rfc822" || subtype == "global" {
            if items.count > 9, let inner = items[8].items {
                let innerSection = inner.first?.items != nil ? section : "\(section).1"
                children = [try node(inner, section: innerSection)]
            }
            position += 3
        }
        let (disposition, dispositionParameters) = dispositionFields(items, at: position + 1)
        return IMAPBodyPart(
            section: section, mediaType: mediaType, subtype: subtype, parameters: pairs(items[2]),
            contentID: items[3].string?.trimmingCharacters(in: CharacterSet(charactersIn: "<> ")),
            encoding: (items[5].string ?? "7bit").lowercased(), size: items[6].int ?? 0,
            disposition: disposition, dispositionParameters: dispositionParameters, children: children)
    }

    private static func dispositionFields(_ items: [IMAPValue], at index: Int) -> (String?, [String: String]) {
        guard index < items.count, let fields = items[index].items, fields.isEmpty == false else { return (nil, [:]) }
        let name = fields[0].string?.lowercased()
        let parameters = fields.count > 1 ? pairs(fields[1]) : [:]
        return (name, parameters)
    }

    private static func pairs(_ value: IMAPValue) -> [String: String] {
        guard let items = value.items else { return [:] }
        var raw: [(String, String)] = []
        var position = 0
        while position + 1 < items.count {
            if let key = items[position].string, let text = items[position + 1].string {
                raw.append((key.lowercased(), text))
            }
            position += 2
        }
        return MailMIME.resolveExtended(raw)
    }
}

struct IMAPFetched: Equatable, Sendable {
    var sequence: Int
    var uid: Int?
    var flags: Set<String> = []
    var internalDate: Date?
    var size: Int?
    var envelope: IMAPEnvelope?
    var structure: IMAPBodyPart?
    var sections: [String: Data] = [:]

    static func parse(_ values: [IMAPValue]) throws -> IMAPFetched? {
        guard values.count >= 3, let sequence = values[0].int, values[1].string?.uppercased() == "FETCH",
              let items = values[2].items else { return nil }
        var fetched = IMAPFetched(sequence: sequence)
        var position = 0
        while position + 1 < items.count {
            let key = (items[position].string ?? "").uppercased()
            let value = items[position + 1]
            switch key {
            case "UID": fetched.uid = value.int
            case "FLAGS": fetched.flags = Set((value.items ?? []).compactMap { $0.string?.lowercased() })
            case "INTERNALDATE": fetched.internalDate = value.string.flatMap(MailMIME.parseInternalDate)
            case "RFC822.SIZE": fetched.size = value.int
            case "ENVELOPE": fetched.envelope = IMAPEnvelope.parse(value)
            case "BODYSTRUCTURE": fetched.structure = try IMAPBodyStructureParser.parse(value)
            default:
                if key.hasPrefix("BODY["), let close = key.firstIndex(of: "]") {
                    let section = String(key[key.index(key.startIndex, offsetBy: 5)..<close])
                    fetched.sections[section] = value.data ?? Data()
                }
            }
            position += 2
        }
        return fetched
    }
}

struct IMAPListEntry: Equatable, Sendable {
    var attributes: Set<String>
    var delimiter: String?
    var path: String

    static func parse(_ values: [IMAPValue]) -> IMAPListEntry? {
        guard values.count >= 4, values[0].string?.uppercased() == "LIST",
              let attributes = values[1].items, let path = values[3].string else { return nil }
        return IMAPListEntry(
            attributes: Set(attributes.compactMap { $0.string?.lowercased() }),
            delimiter: values[2].string,
            path: IMAPModifiedUTF7.decode(path))
    }

    var isSelectable: Bool {
        attributes.contains("\\noselect") == false && attributes.contains("\\nonexistent") == false
    }

    var displayName: String {
        guard let delimiter, delimiter.isEmpty == false,
              let last = path.components(separatedBy: delimiter).last, last.isEmpty == false else { return path }
        return last
    }

    var role: MailFolderRole {
        if path.uppercased() == "INBOX" { return .inbox }
        if attributes.contains("\\sent") { return .sent }
        if attributes.contains("\\drafts") { return .drafts }
        if attributes.contains("\\trash") { return .trash }
        if attributes.contains("\\junk") { return .spam }
        if attributes.contains("\\archive") { return .archive }
        switch displayName.lowercased().filter({ $0.isWhitespace == false }) {
        case "sent", "sentitems", "sentmessages", "sentmail", "gesendet", "gesendeteelemente", "gesendeteobjekte":
            return .sent
        case "drafts", "draft", "entw\u{FC}rfe", "entwurf":
            return .drafts
        case "trash", "deleteditems", "deletedmessages", "papierkorb", "gel\u{F6}scht", "gel\u{F6}schteelemente", "gel\u{F6}schteobjekte":
            return .trash
        case "spam", "junk", "junke-mail", "junk-e-mail", "bulkmail":
            return .spam
        case "archive", "archives", "archiv":
            return .archive
        default:
            return .other
        }
    }
}

struct IMAPMessageReference: Equatable, Sendable {
    var folder: String
    var uidValidity: Int
    var uid: Int

    var encoded: String { "\(uidValidity):\(uid):\(folder)" }

    static func decode(_ text: String) throws -> IMAPMessageReference {
        let parts = text.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3, let validity = Int(parts[0]), let uid = Int(parts[1]), parts[2].isEmpty == false else {
            throw MailTransportError.invalidMessageID(text)
        }
        return IMAPMessageReference(folder: String(parts[2]), uidValidity: validity, uid: uid)
    }
}
