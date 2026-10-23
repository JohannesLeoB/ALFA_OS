import Foundation
import Pages

public enum DocFile {
    public static let namespace = "https://alfa.app/draws"
    static let tag = "doc"

    public static func json(_ doc: DrawsDoc) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let raw = try? encoder.encode(doc), let text = String(data: raw, encoding: .utf8) else { throw DocError.encode }
        var out = String.UnicodeScalarView()
        for c in text.unicodeScalars {
            switch c.value {
            case 0xFFFE, 0xFFFF: out.append(contentsOf: String(format: "\\u%04X", c.value).unicodeScalars)
            case 0..<0x20 where c != "\t" && c != "\n" && c != "\r": out.append(contentsOf: String(format: "\\u%04X", c.value).unicodeScalars)
            case 0x3C: out.append(contentsOf: "\\u003C".unicodeScalars)
            default: out.append(c)
            }
        }
        return Data(String(out).replacingOccurrences(of: "]]>", with: "]]\\u003E").utf8)
    }

    public static func write(_ doc: DrawsDoc, sheet: Sheet) throws -> Data {
        let body = try json(doc)
        guard let text = String(data: body, encoding: .utf8) else { throw DocError.encode }
        let svg = SVGRenderer().svg(sheet.page, fonts: sheet.faces)
        guard let cut = svg.firstIndex(of: "\n") else { throw DocError.encode }
        let meta = "<metadata><draws:\(tag) xmlns:draws=\"\(namespace)\"><![CDATA[\(text)]]></draws:\(tag)></metadata>"
        return Data((svg[..<cut] + "\n" + meta + svg[cut...]).utf8)
    }

    public static func read(_ data: Data) throws -> DrawsDoc? {
        guard let body = try Scan.body(data) else { return nil }
        struct Head: Decodable { var schema: Int? }
        guard let head = try? JSONDecoder().decode(Head.self, from: body) else { throw DocError.corrupt }
        if let schema = head.schema, schema > DrawsDoc.schema { throw DocError.newer(schema) }
        guard let doc = try? JSONDecoder().decode(DrawsDoc.self, from: body) else { throw DocError.corrupt }
        return doc
    }

    public static func svg(_ doc: DrawsDoc, shelf: PackShelf, fonts: SheetFonts) throws -> Data {
        let sheets = try shelf.sheets(doc, fonts: fonts)
        guard sheets.indices.contains(doc.render.page) else { throw DocError.missing("page") }
        return try write(doc, sheet: sheets[doc.render.page])
    }
}

private enum Scan {
    static func find(_ needle: [UInt8], in hay: Data, from: Int) -> Int? {
        guard let first = needle.first, from < hay.endIndex else { return nil }
        var at = from
        while let hit = hay[at...].firstIndex(of: first) {
            if hit + needle.count > hay.endIndex { return nil }
            if hay[hit..<hit + needle.count].elementsEqual(needle) { return hit }
            at = hit + 1
        }
        return nil
    }

    static func names(_ data: Data) -> [String] {
        var out: [String] = []
        for quote in ["\"", "'"] {
            let needle = Array((quote + DocFile.namespace + quote).utf8)
            var from = data.startIndex
            while let hit = find(needle, in: data, from: from) {
                from = hit + needle.count
                guard hit > data.startIndex, data[hit - 1] == UInt8(ascii: "=") else { continue }
                var start = hit - 1
                while start > data.startIndex, data[start - 1] != 0x20, data[start - 1] != 0x0A, data[start - 1] != 0x09, data[start - 1] != 0x0D { start -= 1 }
                let attr = String(decoding: data[start..<hit - 1], as: UTF8.self)
                if attr == "xmlns" { out.append(DocFile.tag) } else if attr.hasPrefix("xmlns:") { out.append(attr.dropFirst(6) + ":" + DocFile.tag) }
            }
        }
        return out
    }

    static func body(_ data: Data) throws -> Data? {
        for name in names(data) {
            let open = Array(("<" + name).utf8)
            var from = data.startIndex
            while let hit = find(open, in: data, from: from) {
                from = hit + open.count
                guard from < data.endIndex, [0x20, 0x0A, 0x09, 0x0D, 0x3E, 0x2F].contains(data[from]) else { continue }
                var quote: UInt8?
                var end = from
                while end < data.endIndex {
                    let c = data[end]
                    if let q = quote { if c == q { quote = nil } } else if c == 0x22 || c == 0x27 { quote = c } else if c == 0x3E { break }
                    end += 1
                }
                guard end < data.endIndex else { throw DocError.corrupt }
                if data[end - 1] == 0x2F { throw DocError.corrupt }
                guard let close = find(Array(("</" + name).utf8), in: data, from: end + 1) else { throw DocError.corrupt }
                return try content(data[(end + 1)..<close])
            }
        }
        return nil
    }

    static func content(_ part: Data) throws -> Data {
        var out = Data()
        var at = part.startIndex
        let open = Array("<![CDATA[".utf8), shut = Array("]]>".utf8)
        while at < part.endIndex {
            if let cdata = find(open, in: part, from: at), cdata == at {
                guard let stop = find(shut, in: part, from: cdata + open.count) else { throw DocError.corrupt }
                out.append(part[(cdata + open.count)..<stop])
                at = stop + shut.count
            } else {
                let next = find(open, in: part, from: at) ?? part.endIndex
                out.append(Data(unescape(part[at..<next])))
                at = next
            }
        }
        return out
    }

    static func unescape(_ raw: Data.SubSequence) -> [UInt8] {
        var out: [UInt8] = []
        out.reserveCapacity(raw.count)
        var i = raw.startIndex
        while i < raw.endIndex {
            if raw[i] == 0x26, let semi = raw[i...].prefix(12).firstIndex(of: 0x3B) {
                let name = String(decoding: raw[(i + 1)..<semi], as: UTF8.self)
                var scalar: Unicode.Scalar?
                switch name {
                case "lt": scalar = "<"
                case "gt": scalar = ">"
                case "amp": scalar = "&"
                case "quot": scalar = "\""
                case "apos": scalar = "'"
                default:
                    if name.hasPrefix("#x") || name.hasPrefix("#X") { scalar = UInt32(name.dropFirst(2), radix: 16).flatMap(Unicode.Scalar.init) }
                    else if name.hasPrefix("#") { scalar = UInt32(name.dropFirst(1)).flatMap(Unicode.Scalar.init) }
                }
                if let scalar {
                    out.append(contentsOf: Array(String(scalar).utf8))
                    i = semi + 1
                    continue
                }
            }
            out.append(raw[i])
            i += 1
        }
        return out
    }
}
