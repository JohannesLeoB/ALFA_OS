import Foundation

extension IMAPSMTPClient {
    private struct PreviewSource: Hashable {
        var section: String
        var encoding: String
        var charset: String?
        var html: Bool
        var limit: Int
    }

    static let previewTextBytes = 4_096
    static let previewHTMLBytes = 16_384
    static let previewWideHTMLBytes = 131_072
    static let previewCharacters = 600
    static let previewEmpty = " "

    static func previews(_ entries: [IMAPFetched], session: IMAPClient) async -> [Int: String] {
        var pending: [Int: [PreviewSource]] = [:]
        for entry in entries {
            guard let uid = entry.uid, let structure = entry.structure else { continue }
            pending[uid] = sources(structure)
        }
        var result: [Int: String] = [:]
        while !pending.isEmpty {
            var groups: [PreviewSource: [Int]] = [:]
            for (uid, list) in pending {
                if let next = list.first {
                    groups[next, default: []].append(uid)
                } else {
                    result[uid] = previewEmpty
                    pending[uid] = nil
                }
            }
            for (source, uids) in groups {
                let item = "BODY.PEEK[\(source.section)]<0.\(source.limit)>"
                guard let fetched = try? await session.fetch(uids: uids, items: ["UID", item]) else {
                    for uid in uids { pending[uid] = nil }
                    continue
                }
                var found: [Int: String] = [:]
                for entry in fetched {
                    guard let uid = entry.uid, let raw = entry.sections[source.section.uppercased()] else { continue }
                    let decoded = MIME.truncatedString(from: MIME.decodeTransfer(raw, encoding: source.encoding), charset: source.charset)
                    found[uid] = snippet(decoded, html: source.html)
                }
                for uid in uids {
                    if let text = found[uid], !PreviewEngine.text(text).isEmpty {
                        result[uid] = text
                        pending[uid] = nil
                    } else {
                        pending[uid]?.removeFirst()
                    }
                }
            }
        }
        return result
    }

    static func snippet(_ decoded: String, html: Bool) -> String {
        let text = html ? HTMLEngine.plain(decoded) : decoded
        let cut = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(previewCharacters))
        return cut.isEmpty ? previewEmpty : cut
    }

    private static func sources(_ structure: IMAPBodyPart) -> [PreviewSource] {
        var list: [PreviewSource] = []
        if let part = structure.firstPlainText {
            list.append(PreviewSource(section: part.section, encoding: part.encoding, charset: part.charset, html: false,
                                      limit: previewTextBytes))
        }
        if let part = structure.firstHTML {
            list.append(PreviewSource(section: part.section, encoding: part.encoding, charset: part.charset, html: true,
                                      limit: previewHTMLBytes))
            if part.size > previewHTMLBytes {
                list.append(PreviewSource(section: part.section, encoding: part.encoding, charset: part.charset, html: true,
                                          limit: previewWideHTMLBytes))
            }
        }
        return list
    }
}
