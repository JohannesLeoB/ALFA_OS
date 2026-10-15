import Foundation
import MykilosKit

struct MailOutgoingMessage: Equatable, Sendable {
    var data: Data
    var sender: String
    var recipients: [String]
}

enum MailMessageBuilder {
    static func build(_ draft: EmailDraft, account: MailAccount, messageID: String = UUID().uuidString.lowercased(),
                      date: Date = Date(), asDraft: Bool = false) throws -> MailOutgoingMessage {
        let sender = try senderMailbox(account)
        let to = try mailboxes(draft.to)
        let cc = try mailboxes(draft.cc)
        let bcc = try mailboxes(draft.bcc)
        let recipients = (to + cc + bcc).map(\.address)
        guard recipients.isEmpty == false || asDraft else { throw MailTransportError.noRecipients }

        let domain = sender.address.split(separator: "@").last.map(String.init) ?? "localhost"
        let boundaryBase = messageID.replacingOccurrences(of: "-", with: "")
        var lines: [String] = []
        lines.append("Date: \(MailMIME.formatMessageDate(date))")
        lines.append("From: \(render(sender))")
        if to.isEmpty == false { lines.append("To: \(to.map(render).joined(separator: ", "))") }
        if cc.isEmpty == false { lines.append("Cc: \(cc.map(render).joined(separator: ", "))") }
        if asDraft, bcc.isEmpty == false { lines.append("Bcc: \(bcc.map(render).joined(separator: ", "))") }
        lines.append("Subject: \(encodeHeader(clean(draft.subject)))")
        lines.append("Message-ID: <\(messageID)@\(domain)>")
        if let reference = draft.inReplyTo?.trimmingCharacters(in: .whitespacesAndNewlines), reference.isEmpty == false {
            let wrapped = reference.hasPrefix("<") ? clean(reference) : "<\(clean(reference))>"
            lines.append("In-Reply-To: \(wrapped)")
            lines.append("References: \(wrapped)")
        }
        lines.append("MIME-Version: 1.0")

        if draft.attachments.isEmpty {
            lines.append(contentsOf: bodyLines(draft, boundary: "alt_\(boundaryBase)"))
        } else {
            let mixed = "mixed_\(boundaryBase)"
            lines.append("Content-Type: multipart/mixed; boundary=\"\(mixed)\"")
            lines.append("")
            lines.append("--\(mixed)")
            lines.append(contentsOf: bodyLines(draft, boundary: "alt_\(boundaryBase)"))
            for attachment in draft.attachments {
                lines.append("--\(mixed)")
                lines.append(contentsOf: attachmentLines(attachment))
            }
            lines.append("--\(mixed)--")
        }
        let text = lines.joined(separator: "\r\n") + "\r\n"
        return MailOutgoingMessage(data: Data(text.utf8), sender: sender.address, recipients: recipients)
    }

    static func senderMailbox(_ account: MailAccount) throws -> (name: String?, address: String) {
        guard let parsed = MailMIME.parseMailbox(account.address) else {
            throw MailTransportError.invalidRecipient(account.address)
        }
        let name = account.displayName.isEmpty || account.displayName == account.address ? nil : account.displayName
        return (name, parsed.address)
    }

    static func mailboxes(_ text: String?) throws -> [(name: String?, address: String)] {
        guard let text, text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return [] }
        return try MailMIME.splitAddresses(text).map { entry in
            guard let parsed = MailMIME.parseMailbox(entry), parsed.address.allSatisfy({ $0.isASCII }) else {
                throw MailTransportError.invalidRecipient(entry)
            }
            return parsed
        }
    }

    static func render(_ mailbox: (name: String?, address: String)) -> String {
        guard let name = mailbox.name, name.isEmpty == false else { return mailbox.address }
        let cleaned = clean(name)
        if cleaned.allSatisfy({ $0.isASCII }) {
            let specials = CharacterSet(charactersIn: "()<>[]:;@\\,.\"")
            if cleaned.unicodeScalars.contains(where: { specials.contains($0) }) {
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
            if size + width > 45 {
                words.append(encodedWord(chunk))
                chunk = ""
                size = 0
            }
            chunk.append(character)
            size += width
        }
        if chunk.isEmpty == false { words.append(encodedWord(chunk)) }
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
            let end = encoded.index(start, offsetBy: 76, limitedBy: encoded.endIndex) ?? encoded.endIndex
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

    private static func bodyLines(_ draft: EmailDraft, boundary: String) -> [String] {
        guard let html = draft.bodyHTML, html.isEmpty == false else { return textPart("text/plain", draft.body) }
        var lines = ["Content-Type: multipart/alternative; boundary=\"\(boundary)\"", "", "--\(boundary)"]
        lines += textPart("text/plain", draft.body)
        lines.append("--\(boundary)")
        lines += textPart("text/html", html)
        lines.append("--\(boundary)--")
        return lines
    }

    private static func attachmentLines(_ attachment: DraftAttachment) -> [String] {
        let mime = validMediaType(attachment.mimeType)
        let name = clean(attachment.filename)
        let escaped = name.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        var parameter = "filename=\"\(name.allSatisfy { $0.isASCII } ? escaped : fallbackName(name))\""
        if name.allSatisfy({ $0.isASCII }) == false {
            let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.-_")
            parameter += "; filename*=UTF-8''" + (name.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")
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
        let pattern = "^[A-Za-z0-9!#$&^_.+-]+/[A-Za-z0-9!#$&^_.+-]+$"
        if value.range(of: pattern, options: .regularExpression) != nil { return value }
        return "application/octet-stream"
    }
}
