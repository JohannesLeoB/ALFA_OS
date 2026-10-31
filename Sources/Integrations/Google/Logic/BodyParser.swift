import Foundation
import Mail

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
