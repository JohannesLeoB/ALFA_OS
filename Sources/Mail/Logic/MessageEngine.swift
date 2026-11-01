import Core
import CoreGraphics
import CoreText
import CryptoKit
import Design
import Foundation

public enum MessageEngine {
    private static let lineWidth = 76
    private static let encodedWordWidth = 45
    private static let mediaTypePattern = "^[A-Za-z0-9!#$&^_.+-]+/[A-Za-z0-9!#$&^_.+-]+$"
    private static let headerSpecials = CharacterSet(charactersIn: "()<>[]:;@\\,.\"")
    private static let filenameAllowed = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.-_")

    typealias Pair = (name: String?, address: String)

    private static let base64Line = 76
    private static let lineBreak = 2

    public static func encodedSize(_ draft: Draft) -> Int {
        let text = draft.body.utf8.count + (draft.bodyHTML?.utf8.count ?? 0)
        return draft.attachments.reduce(text) { total, attachment in
            let encoded = (attachment.data.count + 2) / 3 * 4
            return total + encoded + encoded / base64Line * lineBreak
        }
    }

    static func build(_ draft: Draft, account: Account, messageID: String = UUID().uuidString.lowercased(),
                             date: Date = Date(), asDraft: Bool = false) throws -> OutgoingMessage {
        let sender = try senderPair(draft, account: account)
        let to = try mailboxes(draft.to)
        let cc = try mailboxes(draft.cc)
        let bcc = try mailboxes(draft.bcc)
        let recipients = (to + cc + bcc).map(\.address)
        guard !recipients.isEmpty || asDraft else { throw MailFailure.noRecipients }
        let domain = sender.address.split(separator: "@").last.map(String.init) ?? "localhost"
        var head: [String] = []
        head.append("Date: \(DateEngine.formatMessageDate(date))")
        head.append("From: \(render(sender))")
        if !to.isEmpty { head.append("To: \(to.map(render).joined(separator: ", "))") }
        if !cc.isEmpty { head.append("Cc: \(cc.map(render).joined(separator: ", "))") }
        if asDraft, !bcc.isEmpty { head.append("Bcc: \(bcc.map(render).joined(separator: ", "))") }
        head.append("Subject: \(encodeHeader(clean(draft.subject)))")
        head.append("Message-ID: <\(messageID)@\(domain)>")
        head += threading(draft) + receipt(draft)
        let data = assemble(draft, head: head, boundaryStem: boundaryStem(messageID))
        return OutgoingMessage(data: data, sender: sender.address, recipients: recipients)
    }

    public static func buildRaw(_ draft: Draft, domain: String) -> Data {
        var head: [String] = []
        if let sender = draftSender(draft) { head.append("From: \(render(sender))") }
        for (label, value) in [("To", draft.to), ("Cc", draft.cc), ("Bcc", draft.bcc)] {
            if let text = value?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                head.append("\(label): \(clean(text))")
            }
        }
        head.append("Subject: \(encodeHeader(clean(draft.subject)))")
        if let id = draft.messageID { head.append("Message-ID: <\(id)@\(domain)>") }
        head += threading(draft) + receipt(draft)
        return assemble(draft, head: head, boundaryStem: boundaryStem(draft.messageID ?? UUID().uuidString.lowercased()))
    }

    private static func boundaryStem(_ messageID: String) -> String {
        messageID.replacingOccurrences(of: "-", with: "")
    }

    private static func receipt(_ draft: Draft) -> [String] {
        guard let address = draft.receiptTo?.trimmingCharacters(in: .whitespacesAndNewlines), !address.isEmpty else { return [] }
        return ["Disposition-Notification-To: <\(clean(address))>"]
    }

    public static func receiptAddress(_ header: String?) -> String? {
        let address = header?.trimmingCharacters(in: CharacterSet(charactersIn: "<> ").union(.whitespacesAndNewlines))
        return address?.isEmpty == false ? address : nil
    }

    private static func threading(_ draft: Draft) -> [String] {
        guard let reference = draft.inReplyTo?.trimmingCharacters(in: .whitespacesAndNewlines), !reference.isEmpty else {
            return []
        }
        let wrapped = reference.hasPrefix("<") ? clean(reference) : "<\(clean(reference))>"
        return ["In-Reply-To: \(wrapped)", "References: \(wrapped)"]
    }

    private static func assemble(_ draft: Draft, head: [String], boundaryStem: String) -> Data {
        var lines = head
        lines.append("MIME-Version: 1.0")
        if draft.attachments.isEmpty {
            lines += bodyLines(draft, boundary: "alt_\(boundaryStem)")
        } else {
            let mixed = "mixed_\(boundaryStem)"
            lines.append("Content-Type: multipart/mixed; boundary=\"\(mixed)\"")
            lines.append("")
            lines.append("--\(mixed)")
            lines += bodyLines(draft, boundary: "alt_\(boundaryStem)")
            for attachment in draft.attachments {
                lines.append("--\(mixed)")
                lines += attachmentLines(attachment)
            }
            lines.append("--\(mixed)--")
        }
        return Data((lines.joined(separator: "\r\n") + "\r\n").utf8)
    }

    public static func sender(_ header: String?) -> Participant? {
        guard let header, let parsed = AddressListParser.parseMailbox(MIME.decodeEncodedWords(header)) else { return nil }
        return Participant(name: parsed.name ?? "", address: parsed.address)
    }

    private static func draftSender(_ draft: Draft) -> Pair? {
        guard let from = draft.from, let parsed = AddressListParser.parseMailbox(from.address) else { return nil }
        let name = clean(from.name).trimmingCharacters(in: .whitespaces)
        return (name.isEmpty ? nil : name, parsed.address)
    }

    private static func senderPair(_ draft: Draft, account: Account) throws -> Pair {
        try draftSender(draft) ?? senderAddress(account)
    }

    static func senderAddress(_ account: Account) throws -> Pair {
        guard let parsed = AddressListParser.parseMailbox(account.address) else {
            throw MailFailure.invalidRecipient(account.address)
        }
        let name = account.displayName.isEmpty || account.displayName == account.address ? nil : account.displayName
        return (name, parsed.address)
    }

    static func mailboxes(_ text: String?) throws -> [Pair] {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return try AddressListParser.split(text).map { entry in
            guard let parsed = AddressListParser.parseMailbox(entry), parsed.address.allSatisfy({ $0.isASCII }) else {
                throw MailFailure.invalidRecipient(entry)
            }
            return parsed
        }
    }

    static func render(_ mailbox: Pair) -> String {
        guard let name = mailbox.name, !name.isEmpty else { return mailbox.address }
        let cleaned = clean(name)
        if cleaned.allSatisfy({ $0.isASCII }) {
            if cleaned.unicodeScalars.contains(where: { headerSpecials.contains($0) }) {
                let escaped = cleaned.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
                return "\"\(escaped)\" <\(mailbox.address)>"
            }
            return "\(cleaned) <\(mailbox.address)>"
        }
        return "\(encodeHeader(cleaned)) <\(mailbox.address)>"
    }

    static func clean(_ text: String) -> String {
        text.replacingOccurrences(of: "\r", with: " ").replacingOccurrences(of: "\n", with: " ")
    }

    static func encodeHeader(_ value: String) -> String {
        if value.allSatisfy({ $0.isASCII }) { return value }
        var words: [String] = []
        var chunk = ""
        var size = 0
        for character in value {
            let width = String(character).utf8.count
            if size + width > encodedWordWidth {
                words.append(encodedWord(chunk))
                chunk = ""
                size = 0
            }
            chunk.append(character)
            size += width
        }
        if !chunk.isEmpty { words.append(encodedWord(chunk)) }
        return words.joined(separator: "\r\n ")
    }

    private static func encodedWord(_ text: String) -> String {
        "=?UTF-8?B?\(Data(text.utf8).base64EncodedString())?="
    }

    static func base64Lines(_ data: Data) -> String {
        let encoded = data.base64EncodedString()
        var lines: [String] = []
        var start = encoded.startIndex
        while start < encoded.endIndex {
            let end = encoded.index(start, offsetBy: lineWidth, limitedBy: encoded.endIndex) ?? encoded.endIndex
            lines.append(String(encoded[start..<end]))
            start = end
        }
        return lines.joined(separator: "\r\n")
    }

    static func normalizedText(_ text: String) -> Data {
        let unified = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        return Data(unified.replacingOccurrences(of: "\n", with: "\r\n").utf8)
    }

    private static func textPart(_ type: String, _ text: String) -> [String] {
        ["Content-Type: \(type); charset=\"UTF-8\"",
         "Content-Transfer-Encoding: base64",
         "",
         base64Lines(normalizedText(text))]
    }

    private static func bodyLines(_ draft: Draft, boundary: String) -> [String] {
        guard let html = draft.bodyHTML, !html.isEmpty else { return textPart("text/plain", draft.body) }
        var lines = ["Content-Type: multipart/alternative; boundary=\"\(boundary)\"", "", "--\(boundary)"]
        lines += textPart("text/plain", draft.body)
        lines.append("--\(boundary)")
        lines += textPart("text/html", html)
        lines.append("--\(boundary)--")
        return lines
    }

    private static func attachmentLines(_ attachment: Attachment) -> [String] {
        let mime = validMediaType(attachment.mimeType)
        let name = clean(attachment.filename)
        let escaped = name.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        var parameter = "filename=\"\(name.allSatisfy { $0.isASCII } ? escaped : fallbackName(name))\""
        if !name.allSatisfy({ $0.isASCII }) {
            parameter += "; filename*=UTF-8''" + (name.addingPercentEncoding(withAllowedCharacters: filenameAllowed) ?? "")
        }
        let typeName = parameter.replacingOccurrences(of: "filename", with: "name")
        return ["Content-Type: \(mime); \(typeName)",
                "Content-Transfer-Encoding: base64",
                "Content-Disposition: attachment; \(parameter)",
                "",
                base64Lines(attachment.data)]
    }

    private static func fallbackName(_ name: String) -> String {
        String(name.map { $0.isASCII && $0 != "\"" && $0 != "\\" ? $0 : "_" })
    }

    private static func validMediaType(_ value: String) -> String {
        if value.range(of: mediaTypePattern, options: .regularExpression) != nil { return value }
        return "application/octet-stream"
    }
}

public enum MessagePDF {
    public static func render(_ message: OpenMessage, page: CGSize, margin: CGFloat) -> Data? {
        let body: String
        switch message.content {
        case .text(let text): body = text
        case .html(let html, _): body = HTMLEngine.plain(html)
        default: body = message.summary.snippet
        }
        let date = message.summary.receivedAt.map { $0.formatted(date: .long, time: .shortened) }
        let head = [message.summary.subject, message.summary.from, date].compactMap { $0 }.filter { !$0.isEmpty }
        return render(text: (head + ["", body]).joined(separator: "\n"), page: page, margin: margin)
    }

    public static func render(text: String, page: CGSize, margin: CGFloat) -> Data? {
        let font = CTFontCreateUIFontForLanguage(.system, Tokens.TextSize.body, nil)
        let key = NSAttributedString.Key(rawValue: kCTFontAttributeName as String)
        return render(NSAttributedString(string: text, attributes: font.map { [key: $0] }), page: page, margin: margin)
    }

    public static func html(template: String, message: OpenMessage) -> String {
        let body: String
        switch message.content {
        case .text(let text): body = text
        case .html(let html, _): body = HTMLEngine.plain(html)
        default: body = message.summary.snippet
        }
        let summary = message.summary
        let names = (message.attachments.isEmpty ? summary.attachments : message.attachments).map(\.filename)
        let values = [
            "subject": summary.subject, "from": summary.fromRaw.isEmpty ? summary.from : summary.fromRaw, "to": summary.toRaw,
            "cc": summary.ccRaw, "date": summary.receivedAt.map { $0.formatted(date: .long, time: .shortened) } ?? "",
            "body": body, "attachments": names.joined(separator: "\n")
        ]
        var filled = template
        for (name, value) in values {
            let escaped = escape(value).replacingOccurrences(of: "\n", with: "<br>")
            for marker in ["{{{\(name)}}}", "{{\(name)}}", "{{ \(name) }}"] {
                filled = filled.replacingOccurrences(of: marker, with: escaped)
            }
        }
        return filled
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }

    public static func render(_ string: NSAttributedString, page: CGSize, margin: CGFloat) -> Data? {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { return nil }
        var box = CGRect(origin: .zero, size: page)
        guard let context = CGContext(consumer: consumer, mediaBox: &box, nil) else { return nil }
        let setter = CTFramesetterCreateWithAttributedString(string)
        let path = CGPath(rect: box.insetBy(dx: margin, dy: margin), transform: nil)
        var start = 0
        repeat {
            context.beginPDFPage(nil)
            let frame = CTFramesetterCreateFrame(setter, CFRange(location: start, length: 0), path, nil)
            CTFrameDraw(frame, context)
            context.endPDFPage()
            let shown = CTFrameGetVisibleStringRange(frame).length
            if shown == 0 { break }
            start += shown
        } while start < string.length
        context.closePDF()
        return data as Data
    }
}

enum AttachmentFileEngine {
    static let nameLimit = 96
    static let extensionLimit = 16
    static let digestBytes = 8
    static let fallbackName = "attachment"
    private static let forbidden = CharacterSet(charactersIn: "/:\\").union(.controlCharacters)

    static func total(_ files: [StoredAttachment]) -> Int {
        files.reduce(0) { $0 + $1.size }
    }

    static func oldestFirst(_ files: [StoredAttachment]) -> [StoredAttachment] {
        files.sorted { left, right in
            if left.age != right.age { return left.age < right.age }
            if left.storedAt != right.storedAt { return left.storedAt < right.storedAt }
            return left.identity < right.identity
        }
    }

    static func evictions(_ files: [StoredAttachment], limit: Int?) -> [StoredAttachment] {
        guard let limit else { return [] }
        var remaining = total(files)
        var gone: [StoredAttachment] = []
        for file in oldestFirst(files) where remaining > limit {
            gone.append(file)
            remaining -= file.size
        }
        return gone
    }

    static func admits(_ incoming: StoredAttachment, among files: [StoredAttachment], limit: Int?) -> Bool {
        let others = files.filter { $0.identity != incoming.identity }
        return !evictions(others + [incoming], limit: limit).contains { $0.identity == incoming.identity }
    }

    static func relativePath(inlet: String, message: String, attachment: String, filename: String) -> String {
        [digest(inlet), digest(message), digest(attachment), safeName(filename)].joined(separator: "/")
    }

    static func inletDirectory(_ inlet: String) -> String {
        digest(inlet)
    }

    static func digest(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).prefix(digestBytes).map { String(format: "%02x", $0) }.joined()
    }

    static func safeName(_ name: String) -> String {
        let replaced = String(String.UnicodeScalarView(name.unicodeScalars.map { forbidden.contains($0) ? "_" : $0 }))
        var cleaned = replaced.trimmingCharacters(in: .whitespacesAndNewlines)
        while cleaned.hasPrefix(".") { cleaned.removeFirst() }
        if cleaned.isEmpty { return fallbackName }
        guard cleaned.utf8.count > nameLimit else { return cleaned }
        let suffix = (cleaned as NSString).pathExtension
        let tail = suffix.isEmpty || suffix.utf8.count > extensionLimit ? "" : "." + suffix
        var stem = String(cleaned.dropLast(tail.count))
        while !stem.isEmpty, stem.utf8.count + tail.utf8.count > nameLimit { stem.removeLast() }
        return stem.isEmpty ? fallbackName + tail : stem + tail
    }
}
