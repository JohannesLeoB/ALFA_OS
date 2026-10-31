import Core
import Foundation
import Mail

enum MessageParser {
    struct ListPage: Equatable {
        var ids: [String]
        var nextPageToken: String?
        var estimate: Int?
    }

    static func listPage(from data: Data) throws -> ListPage {
        struct Reference: Decodable { var id: String }
        struct Response: Decodable {
            var messages: [Reference]?
            var nextPageToken: String?
            var resultSizeEstimate: Int?
        }
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data) else { throw GoogleFailure.decodingFailed }
        return ListPage(ids: (decoded.messages ?? []).map(\.id), nextPageToken: decoded.nextPageToken,
                        estimate: decoded.resultSizeEstimate)
    }

    struct HistoryPage: Equatable {
        var ids: Set<String>
        var historyID: String?
        var nextPageToken: String?
    }

    static func historyPage(from data: Data) throws -> HistoryPage {
        struct Reference: Decodable { var id: String }
        struct Change: Decodable { var message: Reference }
        struct Record: Decodable {
            var messages: [Reference]?
            var labelsAdded: [Change]?
            var labelsRemoved: [Change]?
        }
        struct Response: Decodable {
            var history: [Record]?
            var historyId: String?
            var nextPageToken: String?
        }
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data) else { throw GoogleFailure.decodingFailed }
        var ids = Set<String>()
        for record in decoded.history ?? [] {
            ids.formUnion((record.messages ?? []).map(\.id))
            ids.formUnion((record.labelsAdded ?? []).map(\.message.id))
            ids.formUnion((record.labelsRemoved ?? []).map(\.message.id))
        }
        return HistoryPage(ids: ids, historyID: decoded.historyId, nextPageToken: decoded.nextPageToken)
    }

    static func profileHistoryID(from data: Data) throws -> String {
        struct Response: Decodable { var historyId: String? }
        guard let id = (try? JSONDecoder().decode(Response.self, from: data))?.historyId else {
            throw GoogleFailure.decodingFailed
        }
        return id
    }

    static func message(from data: Data) throws -> GmailMessage {
        guard let resource = try? JSONDecoder().decode(GmailMessageResource.self, from: data) else {
            throw GoogleFailure.decodingFailed
        }
        return map(resource)
    }

    static func thread(from data: Data) -> [GmailMessage] {
        struct Response: Decodable { var messages: [GmailMessageResource]? }
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data) else { return [] }
        return (decoded.messages ?? []).map(map)
    }

    static func labelCount(from data: Data) -> FolderCount? {
        struct Response: Decodable {
            var messagesUnread: Int?
            var messagesTotal: Int?
        }
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data),
              let unread = decoded.messagesUnread, let total = decoded.messagesTotal else { return nil }
        return FolderCount(unseen: unread, total: total)
    }

    static func labels(from data: Data) -> [GmailLabel] {
        struct Entry: Decodable {
            var id: String?
            var name: String?
            var type: String?
        }
        struct Response: Decodable { var labels: [Entry]? }
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data) else { return [] }
        return (decoded.labels ?? [])
            .filter { $0.type == "user" }
            .compactMap { entry in
                guard let id = entry.id, let name = entry.name else { return nil }
                return GmailLabel(id: id, name: name)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func senderName(from raw: String) -> String {
        guard let bracket = raw.firstIndex(of: "<") else { return raw }
        let name = raw[raw.startIndex..<bracket].trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = name.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        return cleaned.isEmpty ? raw : cleaned
    }

    private static let namedEntities = ["amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " "]
    private static let longestEntity = 8

    static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = ""
        var rest = Substring(text)
        while let amp = rest.firstIndex(of: "&") {
            result += rest[..<amp]
            let after = rest[rest.index(after: amp)...]
            if let semicolon = after.firstIndex(of: ";"),
               after.distance(from: after.startIndex, to: semicolon) <= longestEntity,
               let value = entity(String(after[..<semicolon])) {
                result += value
                rest = after[after.index(after: semicolon)...]
            } else {
                result += "&"
                rest = after
            }
        }
        return result + rest
    }

    private static func entity(_ name: String) -> String? {
        if name.hasPrefix("#x") || name.hasPrefix("#X") {
            return UInt32(name.dropFirst(2), radix: 16).flatMap(Unicode.Scalar.init).map { String(Character($0)) }
        }
        if name.hasPrefix("#") {
            return UInt32(name.dropFirst()).flatMap(Unicode.Scalar.init).map { String(Character($0)) }
        }
        return namedEntities[name]
    }

    static func emailDate(_ string: String) -> Date? {
        var text = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasSuffix(")"), let open = text.firstIndex(of: "(") {
            text = String(text[..<open]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in dateFormats {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }

    private static let dateFormats = [
        "EEE, d MMM yyyy HH:mm:ss Z",
        "d MMM yyyy HH:mm:ss Z",
        "EEE, d MMM yyyy HH:mm:ss z",
        "EEE, d MMM yyyy HH:mm Z",
        "d MMM yyyy HH:mm Z",
    ]

    private static func internalDate(_ string: String?) -> Date? {
        guard let string, let milliseconds = Double(string) else { return nil }
        return Date(timeIntervalSince1970: milliseconds / 1000)
    }

    private static func map(_ resource: GmailMessageResource) -> GmailMessage {
        let headers = resource.payload?.headers ?? []
        func header(_ name: String) -> String? {
            headers.first(where: { $0.name.lowercased() == name.lowercased() })?.value
        }
        let fromRaw = header("From") ?? ""
        return GmailMessage(
            id: resource.id,
            threadID: resource.threadId ?? "",
            subject: header("Subject") ?? "",
            from: senderName(from: fromRaw),
            fromRaw: fromRaw,
            toRaw: header("To") ?? "",
            ccRaw: header("Cc") ?? "",
            bccRaw: header("Bcc") ?? "",
            replyToRaw: header("Reply-To") ?? "",
            snippet: decodeEntities(resource.snippet ?? ""),
            receivedAt: internalDate(resource.internalDate) ?? header("Date").flatMap(emailDate),
            labels: resource.labelIds ?? [],
            attachments: BodyParser.attachments(in: resource.payload?.parts ?? []),
            messageIDHeader: header("Message-ID") ?? "",
            likelyAttachments: (header("Content-Type") ?? "").lowercased().hasPrefix("multipart/mixed"))
    }
}

enum BodyParser {
    static func plain(from data: Data) -> String {
        guard let resource = try? JSONDecoder().decode(GmailMessageResource.self, from: data) else { return "" }
        return plain(of: resource)
    }

    static func plain(of resource: GmailMessageResource) -> String {
        if let text = firstPart(resource.payload, mime: "text/plain") { return text }
        if let html = firstPart(resource.payload, mime: "text/html") { return HTMLEngine.plain(html) }
        return resource.snippet ?? ""
    }

    static func html(of resource: GmailMessageResource) -> String? {
        firstPart(resource.payload, mime: "text/html")
    }

    static func mailBody(from data: Data) -> GmailMailBody {
        guard let resource = try? JSONDecoder().decode(GmailMessageResource.self, from: data) else {
            return GmailMailBody()
        }
        let text = firstPart(resource.payload, mime: "text/plain")
        let html = firstPart(resource.payload, mime: "text/html")
        var inline: [String: String] = [:]
        collectInlineImages(resource.payload?.parts ?? [], into: &inline)
        let attachments = attachments(in: resource.payload?.parts ?? [])
        let headers = resource.payload?.headers ?? []
        func header(_ name: String) -> String? { headers.first { $0.name.lowercased() == name }?.value }
        return GmailMailBody(text: text == nil && html == nil ? resource.snippet : text, html: html, inlineImages: inline,
                             attachments: attachments, listUnsubscribe: header("list-unsubscribe"),
                             listUnsubscribePost: header("list-unsubscribe-post"))
    }

    static func attachments(in parts: [GmailPart]) -> [GmailAttachment] {
        var result: [GmailAttachment] = []
        for part in parts {
            if let subParts = part.parts { result += attachments(in: subParts) }
            guard let filename = part.filename, !filename.isEmpty,
                  let attachmentID = part.body?.attachmentId, !attachmentID.isEmpty else { continue }
            result.append(GmailAttachment(attachmentID: attachmentID, filename: filename,
                                          mimeType: part.mimeType ?? "application/octet-stream",
                                          sizeBytes: part.body?.size ?? 0))
        }
        return result
    }

    private static func collectInlineImages(_ parts: [GmailPart], into map: inout [String: String]) {
        for part in parts {
            if let sub = part.parts { collectInlineImages(sub, into: &map) }
            guard let attachmentID = part.body?.attachmentId, !attachmentID.isEmpty else { continue }
            let cid = part.headers?.first(where: { $0.name.lowercased() == "content-id" })?.value
                .trimmingCharacters(in: CharacterSet(charactersIn: "<> "))
            if let cid, !cid.isEmpty { map[cid] = attachmentID }
        }
    }

    private static func firstPart(_ payload: GmailPayload?, mime: String) -> String? {
        guard let payload else { return nil }
        if payload.mimeType == mime, let decoded = decode(payload.body?.data, headers: payload.headers) { return decoded }
        for part in payload.parts ?? [] {
            if let found = firstPart(in: part, mime: mime) { return found }
        }
        return nil
    }

    private static func firstPart(in part: GmailPart, mime: String) -> String? {
        if part.mimeType == mime, let decoded = decode(part.body?.data, headers: part.headers) { return decoded }
        for sub in part.parts ?? [] {
            if let found = firstPart(in: sub, mime: mime) { return found }
        }
        return nil
    }

    private static func decode(_ data: String?, headers: [GmailHeader]?) -> String? {
        guard let data, !data.isEmpty, let bytes = URLSafeEngine.decodeURL(data) else { return nil }
        let contentType = headers?.first { $0.name.lowercased() == "content-type" }?.value
        return FlowedEngine.text(bytes, contentType: contentType)
    }
}

enum SenderParser {
    static let acceptedStatus = "accepted"

    static func senders(from data: Data) -> [Participant] {
        struct Entry: Decodable {
            var sendAsEmail: String?
            var displayName: String?
            var isDefault: Bool?
            var verificationStatus: String?
        }
        struct Response: Decodable { var sendAs: [Entry]? }
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data) else { return [] }
        let usable = (decoded.sendAs ?? []).filter {
            $0.sendAsEmail?.isEmpty == false && ($0.verificationStatus == nil || $0.verificationStatus == acceptedStatus)
        }
        let ordered = usable.filter { $0.isDefault == true } + usable.filter { $0.isDefault != true }
        return ordered.enumerated().map { index, entry in
            Participant(id: index, name: entry.displayName ?? "", address: entry.sendAsEmail ?? "")
        }
    }
}

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
        var bodyHTML: String?
        var attachmentRefs: [AttachmentRef]
        var threadID: String?
        var inReplyTo: String?
        var receiptTo: String?
        var from: Participant?

        func draft(with attachments: [Attachment]) -> Draft {
            Draft(to: to, cc: cc, bcc: bcc, subject: subject, body: body, attachments: attachments,
                  inReplyTo: inReplyTo, threadID: threadID, bodyHTML: bodyHTML, receiptTo: receiptTo, from: from)
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
            subject: header("Subject") ?? "", body: BodyParser.plain(of: message), bodyHTML: BodyParser.html(of: message), attachmentRefs: refs,
            threadID: thread?.isEmpty == false ? thread : nil,
            inReplyTo: header("In-Reply-To") ?? header("References"),
            receiptTo: MessageEngine.receiptAddress(header("Disposition-Notification-To")),
            from: MessageEngine.sender(header("From")))
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

enum DraftMimeEngine {
    static let messageIDDomain = "mail.gmail.com"

    static func payload(_ draft: Draft) -> [String: String] {
        var message = ["raw": URLSafeEngine.encodeURL(MessageEngine.buildRaw(draft, domain: messageIDDomain))]
        if let thread = draft.threadID?.trimmingCharacters(in: .whitespacesAndNewlines), !thread.isEmpty {
            message["threadId"] = thread
        }
        return message
    }
}
