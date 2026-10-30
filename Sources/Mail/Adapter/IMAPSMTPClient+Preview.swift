import Foundation

extension IMAPSMTPClient {
    private struct PreviewSource: Hashable {
        var section: String
        var encoding: String
        var charset: String?
        var html: Bool
    }

    static let previewTextBytes = 4_096
    static let previewHTMLBytes = 16_384
    static let previewCharacters = 600
    static let previewEmpty = " "

    static func previews(_ entries: [IMAPFetched], session: IMAPClient) async -> [Int: String] {
        var groups: [PreviewSource: [Int]] = [:]
        for entry in entries {
            guard let uid = entry.uid, let structure = entry.structure,
                  let part = structure.firstPlainText ?? structure.firstHTML else { continue }
            let source = PreviewSource(section: part.section, encoding: part.encoding, charset: part.charset, html: part.mimeType == "text/html")
            groups[source, default: []].append(uid)
        }
        var result: [Int: String] = [:]
        for (source, uids) in groups {
            let limit = source.html ? previewHTMLBytes : previewTextBytes
            guard let fetched = try? await session.fetch(uids: uids, items: ["UID", "BODY.PEEK[\(source.section)]<0.\(limit)>"]) else { continue }
            for entry in fetched {
                guard let uid = entry.uid, let raw = entry.sections[source.section.uppercased()] else { continue }
                let decoded = MIME.truncatedString(from: MIME.decodeTransfer(raw, encoding: source.encoding), charset: source.charset)
                result[uid] = snippet(decoded, html: source.html)
            }
        }
        for entry in entries {
            if let uid = entry.uid, result[uid] == nil, entry.structure != nil { result[uid] = previewEmpty }
        }
        return result
    }

    static func snippet(_ decoded: String, html: Bool) -> String {
        let text = html ? HTMLEngine.plain(decoded) : decoded
        let cut = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(previewCharacters))
        return cut.isEmpty ? previewEmpty : cut
    }
}
