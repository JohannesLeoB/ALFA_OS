import Foundation

enum Csv {
    static func delimiter(_ text: String) -> UInt32 {
        let order: [UInt32] = [44, 59, 9]
        var counts = [0, 0, 0]
        var quoted = false
        for c in text.unicodeScalars {
            if c == "\"" { quoted.toggle() } else if quoted { continue } else if c == "\n" || c == "\r" {
                if counts.contains(where: { $0 > 0 }) { break }
            } else if let i = order.firstIndex(of: c.value) { counts[i] += 1 }
        }
        let best = counts.max() ?? 0
        return best > 0 ? (counts.firstIndex(of: best).map { order[$0] } ?? 44) : 44
    }

    static func parse(_ text: String) -> [[String]] {
        let sep = delimiter(text)
        let scalars = Array(text.unicodeScalars)
        var rows: [[String]] = [], row: [String] = [], field = String.UnicodeScalarView(), quoted = false, at = 0
        func close() { row.append(String(field)); field = String.UnicodeScalarView() }
        func end() { close(); if row != [""] { rows.append(row) }; row = [] }
        while at < scalars.count {
            let c = scalars[at]
            if quoted {
                if c == "\"" {
                    if at + 1 < scalars.count, scalars[at + 1] == "\"" { field.append(c); at += 1 } else { quoted = false }
                } else { field.append(c) }
            } else if c == "\"", field.isEmpty {
                quoted = true
            } else if c.value == sep {
                close()
            } else if c == "\n" || c == "\r" {
                if c == "\r", at + 1 < scalars.count, scalars[at + 1] == "\n" { at += 1 }
                end()
            } else { field.append(c) }
            at += 1
        }
        if !field.isEmpty || !row.isEmpty { end() }
        return rows
    }

    static func read(_ data: Data, _ r: inout Ingested) {
        let rows = parse(Decode.string(data))
        r.tables = [Rows(name: "", rows: rows)]
        r.text = join(rows)
    }

    static func join(_ rows: [[String]]) -> String {
        rows.map { $0.joined(separator: "\t") }.joined(separator: "\n")
    }
}

enum Xlsx {
    static let rowCap = 200_000
    static let colCap = 16_384

    static func read(_ data: Data, _ r: inout Ingested) throws {
        guard let zip = Zip.open(data), let book = Dom.parse(Zip.file(zip, "xl/workbook.xml")) else { throw Failure.damaged(.xlsx) }
        var targets: [String: String] = [:]
        for rel in Dom.parse(Zip.file(zip, "xl/_rels/workbook.xml.rels"))?.all("Relationship") ?? [] {
            targets[rel.attrs["Id"] ?? ""] = rel.attrs["Target"]
        }
        let shared = (Dom.parse(Zip.file(zip, "xl/sharedStrings.xml"))?.all("si") ?? []).map(plain)
        var lines: [String] = []
        for sheet in book.all("sheet") {
            let target = targets[sheet.attrs["r:id"] ?? ""] ?? ""
            let path = target.hasPrefix("/") ? String(target.dropFirst()) : "xl/" + target
            guard let doc = Dom.parse(Zip.file(zip, path)) else { r.note("xlsx.sheet"); continue }
            let rows = grid(doc, shared, &r)
            r.tables.append(Rows(name: sheet.attrs["name"] ?? "", rows: rows))
            lines.append(Csv.join(rows))
        }
        r.text = lines.joined(separator: "\n")
    }

    static func plain(_ node: Node) -> String {
        node.kids.map { $0.name == "t" ? $0.text : ($0.name == "r" ? plain($0) : "") }.joined()
    }

    static func column(_ ref: String) -> Int? {
        var n = 0
        for c in ref.unicodeScalars {
            guard c.value >= 65, c.value <= 90 else { break }
            n = n * 26 + Int(c.value) - 64
        }
        return n == 0 ? nil : n - 1
    }

    static func grid(_ doc: Node, _ shared: [String], _ r: inout Ingested) -> [[String]] {
        var rows: [[String]] = [], width = 0
        for (rowAt, row) in (doc.first("sheetData")?.kids ?? []).filter({ $0.name == "row" }).enumerated() {
            let number = (Int(row.attrs["r"] ?? "") ?? rowAt + 1) - 1
            guard number >= 0, number < rowCap else { r.note("xlsx.truncated"); continue }
            var cells: [Int: String] = [:]
            for (cellAt, cell) in row.kids.filter({ $0.name == "c" }).enumerated() {
                let col = column(cell.attrs["r"] ?? "") ?? cellAt
                guard col < colCap else { r.note("xlsx.truncated"); continue }
                if cell.first("f") != nil { r.note("xlsx.formula") }
                cells[col] = value(cell, shared)
            }
            while rows.count <= number { rows.append([]) }
            let used = (cells.keys.max() ?? -1) + 1
            width = max(width, used)
            rows[number] = (0..<used).map { cells[$0] ?? "" }
        }
        return rows.map { $0 + Array(repeating: "", count: width - $0.count) }
    }

    static func value(_ cell: Node, _ shared: [String]) -> String {
        let raw = cell.first("v")?.text ?? ""
        switch cell.attrs["t"] ?? "n" {
        case "s": return Int(raw).flatMap { shared.indices.contains($0) ? shared[$0] : nil } ?? ""
        case "inlineStr": return cell.first("is").map(plain) ?? ""
        case "b": return raw == "1" ? "TRUE" : "FALSE"
        default: return raw
        }
    }
}
