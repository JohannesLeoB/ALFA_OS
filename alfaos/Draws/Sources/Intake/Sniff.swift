import Foundation
import UniformTypeIdentifiers
import ZIPFoundation

enum Sniff {
    static let brands: Set<String> = ["heic", "heix", "hevc", "hevx", "heim", "heis", "mif1", "msf1"]

    static func kind(_ data: Data, _ name: String) -> Kind {
        let ext = (name as NSString).pathExtension.lowercased()
        if let found = magic(data) { return found }
        let binary = data.prefix(2048).contains(0)
        if !binary, let found = textual(data, ext) { return found }
        if let found = byType(ext) { return found }
        return binary ? .unknown : .text
    }

    static func magic(_ data: Data) -> Kind? {
        let head = [UInt8](data.prefix(16))
        if data.prefix(1024).range(of: Data("%PDF-".utf8)) != nil { return .pdf }
        if head.starts(with: [0x89, 0x50, 0x4e, 0x47]) { return .png }
        if head.starts(with: [0xff, 0xd8, 0xff]) { return .jpeg }
        if head.starts(with: Array("GIF8".utf8)) { return .gif }
        if head.count >= 12, head.starts(with: Array("RIFF".utf8)), Array(head[8..<12]) == Array("WEBP".utf8) { return .webp }
        if head.count >= 12, Array(head[4..<8]) == Array("ftyp".utf8), brands.contains(String(decoding: head[8..<12], as: UTF8.self)) { return .heic }
        if head.count >= 6, head.starts(with: Array("AC10".utf8)), head[4...5].allSatisfy({ $0 >= 0x30 && $0 <= 0x39 }) { return .dwg }
        if head.starts(with: Array("AutoCAD Binary DXF".utf8)) { return .dxf }
        if head.starts(with: [0x50, 0x4b, 0x03, 0x04]) { return package(data) }
        return nil
    }

    static func package(_ data: Data) -> Kind {
        guard let archive = try? Archive(data: data, accessMode: .read, pathEncoding: nil) else { return .unknown }
        if archive["xl/workbook.xml"] != nil { return .xlsx }
        if archive["designmap.xml"] != nil { return .idml }
        return .unknown
    }

    static func textual(_ data: Data, _ ext: String) -> Kind? {
        let head = Decode.string(data.prefix(4096)).trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = head.lowercased()
        if ext == "mustache" { return .mustache }
        if lower.hasPrefix("<svg") || (lower.hasPrefix("<?xml") && lower.contains("<svg")) { return .svg }
        if lower.hasPrefix("<!doctype html") || lower.contains("<html") || ["html", "htm"].contains(ext) {
            return Braces.has(Decode.string(data)) ? .mustache : .html
        }
        if ext == "dxf" || isDxf(head) { return .dxf }
        if ext == "json" || (head.first.map { "{[".contains($0) } ?? false) && (try? JSONSerialization.jsonObject(with: data)) != nil { return .json }
        if ["csv", "tsv"].contains(ext) { return .csv }
        return nil
    }

    static func isDxf(_ head: String) -> Bool {
        let lines = head.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
        var at = 0
        if lines.count > 1, lines[0] == "999" { at = 2 }
        return lines.count > at + 1 && lines[at] == "0" && lines[at + 1].uppercased() == "SECTION"
    }

    static func byType(_ ext: String) -> Kind? {
        guard !ext.isEmpty, let type = UTType(filenameExtension: ext) else { return nil }
        let table: [(UTType, Kind)] = [(.pdf, .pdf), (.png, .png), (.jpeg, .jpeg), (.gif, .gif), (.heic, .heic), (.webP, .webp), (.svg, .svg),
                                       (.html, .html), (.commaSeparatedText, .csv), (.tabSeparatedText, .csv), (.json, .json), (.plainText, .text)]
        return table.first { type.conforms(to: $0.0) }?.1
    }
}

enum Decode {
    static func string(_ data: Data) -> String {
        if data.starts(with: [0xff, 0xfe]) || data.starts(with: [0xfe, 0xff]) { return String(data: data, encoding: .utf16) ?? "" }
        let body = data.starts(with: [0xef, 0xbb, 0xbf]) ? data.dropFirst(3) : data[...]
        return String(data: Data(body), encoding: .utf8) ?? String(data: Data(body), encoding: .windowsCP1252) ?? String(decoding: body, as: UTF8.self)
    }
}
