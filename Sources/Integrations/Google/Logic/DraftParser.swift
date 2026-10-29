import Core
import Foundation
import Mail

enum DraftParser {
    struct Content: Equatable {
        struct AttachmentRef: Equatable {
            var attachmentID: String
            var filename: String
            var mimeType: String
        }

        var messageID: String
        var to: String?
        var cc: String?
        var bcc: String?
        var subject: String
        var body: String
        var attachmentRefs: [AttachmentRef]
        var threadID: String?
        var inReplyTo: String?
        var receiptTo: String?

        func draft(with attachments: [Attachment]) -> Draft {
            Draft(to: to, cc: cc, bcc: bcc, subject: subject, body: body, attachments: attachments,
                  inReplyTo: inReplyTo, threadID: threadID, receiptTo: receiptTo)
        }
    }

    static func content(from data: Data) -> Content? {
        struct Response: Decodable { var message: GmailMessageResource? }
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data),
              let message = decoded.message else { return nil }
        let headers = message.payload?.headers ?? []
        func header(_ name: String) -> String? {
            let value = headers.first(where: { $0.name.lowercased() == name.lowercased() })?.value
            return value?.isEmpty == false ? value : nil
        }
        let refs = BodyParser.attachments(in: message.payload?.parts ?? []).map {
            Content.AttachmentRef(attachmentID: $0.attachmentID, filename: $0.filename, mimeType: $0.mimeType)
        }
        let thread = message.threadId?.trimmingCharacters(in: .whitespacesAndNewlines)
        return Content(
            messageID: message.id, to: header("To"), cc: header("Cc"), bcc: header("Bcc"),
            subject: header("Subject") ?? "", body: BodyParser.plain(of: message), attachmentRefs: refs,
            threadID: thread?.isEmpty == false ? thread : nil,
            inReplyTo: header("In-Reply-To") ?? header("References"),
            receiptTo: MessageEngine.receiptAddress(header("Disposition-Notification-To")))
    }

    static func idMap(from data: Data) -> [String: String] {
        struct Message: Decodable { var id: String? }
        struct Reference: Decodable {
            var id: String?
            var message: Message?
        }
        struct Response: Decodable { var drafts: [Reference]? }
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data) else { return [:] }
        var map: [String: String] = [:]
        for reference in decoded.drafts ?? [] {
            if let draftID = reference.id, let messageID = reference.message?.id { map[messageID] = draftID }
        }
        return map
    }

    static func saved(from data: Data) -> SavedDraft? {
        struct Message: Decodable { var id: String? }
        struct Response: Decodable {
            var id: String?
            var message: Message?
        }
        guard let response = try? JSONDecoder().decode(Response.self, from: data), let id = response.id else { return nil }
        return SavedDraft(id: id, mirrorID: response.message?.id ?? id)
    }
}
