import Foundation

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
            case "INTERNALDATE": fetched.internalDate = value.string.flatMap(DateEngine.parseInternalDate)
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

struct IMAPEnvelope: Equatable, Sendable {
    private static let fieldCount = 10

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
        guard let items = value.items, items.count >= fieldCount else { return nil }
        return IMAPEnvelope(
            date: items[0].string,
            subject: items[1].string.map(MIME.decodeEncodedWords),
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

struct IMAPAddress: Equatable, Sendable {
    var name: String?
    var mailbox: String
    var host: String

    var address: String { "\(mailbox)@\(host)" }

    private var decodedName: String {
        name.map(MIME.decodeEncodedWords)?.trimmingCharacters(in: .whitespaces) ?? ""
    }

    var display: String {
        decodedName.isEmpty ? address : decodedName
    }

    var raw: String {
        let decoded = decodedName
        guard !decoded.isEmpty else { return address }
        let specials = CharacterSet(charactersIn: "()<>[]:;@\\,.\"")
        let needsQuotes = decoded.unicodeScalars.contains { specials.contains($0) }
        let shown = needsQuotes
            ? "\"" + decoded.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
            : decoded
        return "\(shown) <\(address)>"
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
    var isFlowed: Bool { mimeType == "text/plain" && parameters["format"]?.lowercased() == "flowed" }
    var deletesSpaces: Bool { parameters["delsp"]?.lowercased() == "yes" }

    private static let structuralTypes: Set<String> = [
        "application/pgp-encrypted", "application/pgp-signature", "application/pkcs7-signature",
        "application/x-pkcs7-signature", "message/delivery-status", "message/disposition-notification",
        "message/feedback-report"
    ]

    var isInlineImage: Bool {
        mediaType == "image" && !(contentID ?? "").isEmpty && disposition != "attachment"
    }

    var isTextCandidate: Bool {
        (mimeType == "text/plain" || mimeType == "text/html") && disposition != "attachment"
    }

    var isStructural: Bool {
        filename == nil && disposition != "attachment" && Self.structuralTypes.contains(mimeType)
    }

    var isAttachment: Bool {
        guard !isMultipart, !isInlineImage, !isStructural, !isTextCandidate else { return false }
        return disposition == "attachment" || filename != nil || mediaType != "text"
    }

    var leaves: [IMAPBodyPart] {
        if isMultipart { return children.flatMap(\.leaves) }
        return [self]
    }

    var attachments: [IMAPBodyPart] { attachments(html: nil, embedded: inlineContentIDs) }

    func attachments(html: String?, embedded: Set<String>) -> [IMAPBodyPart] {
        let bodies = Set([firstPlainText, firstHTML].compactMap { $0?.section })
        let drawn = firstHTML != nil
        let referenced = html.map(HTMLEngine.inlineReferences) ?? []
        return leaves.filter { part in
            if part.isTextCandidate { return part.filename != nil && !bodies.contains(part.section) }
            guard part.isInlineImage, let contentID = part.contentID else { return part.isAttachment }
            guard drawn else { return true }
            let key = contentID.lowercased()
            guard embedded.contains(key) else { return true }
            return html != nil && !referenced.contains(key)
        }
    }

    private var bodyParts: [IMAPBodyPart] {
        let candidates = leaves.filter(\.isTextCandidate)
        let unnamed = candidates.filter { $0.filename == nil }
        let pool = unnamed.isEmpty ? candidates.filter { $0.disposition == "inline" } : unnamed
        return ["text/plain", "text/html"].compactMap { type in pool.first { $0.mimeType == type } }
    }

    var firstPlainText: IMAPBodyPart? {
        bodyParts.first { $0.mimeType == "text/plain" }
    }

    var firstHTML: IMAPBodyPart? {
        bodyParts.first { $0.mimeType == "text/html" }
    }

    var inlineContentIDs: Set<String> {
        Set(inlineImages.compactMap { $0.contentID?.lowercased() }.filter { !$0.isEmpty })
    }

    var inlineImages: [IMAPBodyPart] {
        leaves.filter { $0.mediaType == "image" && $0.contentID != nil }
    }
}

struct IMAPMessageReference: Equatable, Sendable {
    var folder: String
    var uidValidity: Int
    var uid: Int

    var encoded: String { "\(uidValidity):\(uid):\(folder)" }

    static func decode(_ text: String) throws -> IMAPMessageReference {
        let parts = text.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3, let validity = Int(parts[0]), let uid = Int(parts[1]), !parts[2].isEmpty else {
            throw MailFailure.invalidMessageID(text)
        }
        return IMAPMessageReference(folder: String(parts[2]), uidValidity: validity, uid: uid)
    }
}

struct HeaderField: Equatable, Sendable {
    var name: String
    var value: String
}
