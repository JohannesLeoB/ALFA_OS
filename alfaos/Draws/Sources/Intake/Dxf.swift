import CoreGraphics
import Foundation

enum Dxf {
    static let units = [0: "none", 1: "in", 2: "ft", 3: "mi", 4: "mm", 5: "cm", 6: "m", 7: "km", 8: "uin", 9: "mil", 10: "yd"]
    static let known: Set<String> = ["LINE", "LWPOLYLINE", "POLYLINE", "VERTEX", "SEQEND", "CIRCLE", "ARC", "TEXT", "MTEXT"]

    struct Pair {
        var code: Int
        var value: String
    }

    static func read(_ data: Data, _ r: inout Ingested) {
        if data.starts(with: Array("AutoCAD Binary DXF".utf8)) {
            r.note("dxf.binary")
            return
        }
        let lines = Decode.string(data).components(separatedBy: .newlines)
        var pairs: [Pair] = []
        var at = 0
        while at + 1 < lines.count {
            if let code = Int(lines[at].trimmingCharacters(in: .whitespaces)) { pairs.append(Pair(code: code, value: lines[at + 1].trimmingCharacters(in: .whitespaces))) }
            at += 2
        }
        var drawing = Drawing(units: "none", layers: [], segments: [], polylines: [], rounds: [], captions: [])
        var section = "", open: Polyline?
        var group: [Pair] = []
        func flush() {
            guard let head = group.first, head.code == 0 else { group = []; return }
            let body = Array(group.dropFirst())
            switch section {
            case "HEADER": break
            case "TABLES": if head.value == "LAYER", let name = body.first(where: { $0.code == 2 })?.value { add(&drawing, name) }
            case "ENTITIES": entity(head.value, body, &drawing, &open, &r)
            default: break
            }
            group = []
        }
        for (index, pair) in pairs.enumerated() {
            if pair.code == 0 {
                flush()
                group = [pair]
                if pair.value == "ENDSEC" { section = "" }
            } else if pair.code == 2, group.first?.value == "SECTION" {
                section = pair.value.uppercased()
                group = []
            } else if section == "HEADER", pair.code == 9, pair.value == "$INSUNITS", index + 1 < pairs.count {
                drawing.units = Int(pairs[index + 1].value).flatMap { units[$0] ?? "unit.\($0)" } ?? "none"
            } else {
                group.append(pair)
            }
        }
        flush()
        if let open { drawing.polylines.append(open) }
        r.drawing = drawing
        r.text = drawing.captions.map(\.text).joined(separator: "\n")
        if drawing.segments.isEmpty && drawing.polylines.isEmpty && drawing.rounds.isEmpty && drawing.captions.isEmpty { r.note("dxf.empty") }
    }

    static func add(_ drawing: inout Drawing, _ layer: String) {
        if !drawing.layers.contains(layer) { drawing.layers.append(layer) }
    }

    static func number(_ body: [Pair], _ code: Int) -> Double? {
        body.first { $0.code == code }.flatMap { Double($0.value) }
    }

    static func point(_ body: [Pair], _ x: Int, _ y: Int) -> CGPoint {
        CGPoint(x: number(body, x) ?? 0, y: number(body, y) ?? 0)
    }

    static func entity(_ type: String, _ body: [Pair], _ drawing: inout Drawing, _ open: inout Polyline?, _ r: inout Ingested) {
        let layer = body.first { $0.code == 8 }?.value ?? "0"
        if !known.contains(type) { r.note("dxf.skip.\(type)"); return }
        add(&drawing, layer)
        switch type {
        case "LINE":
            drawing.segments.append(Segment(layer: layer, from: point(body, 10, 20), to: point(body, 11, 21)))
        case "LWPOLYLINE":
            var points: [CGPoint] = [], x: Double?
            for pair in body {
                if pair.code == 10 { x = Double(pair.value) } else if pair.code == 20, let px = x, let py = Double(pair.value) { points.append(CGPoint(x: px, y: py)); x = nil }
            }
            drawing.polylines.append(Polyline(layer: layer, points: points, closed: (Int(body.first { $0.code == 70 }?.value ?? "") ?? 0) & 1 == 1))
        case "POLYLINE":
            if let open { drawing.polylines.append(open) }
            open = Polyline(layer: layer, points: [], closed: (Int(body.first { $0.code == 70 }?.value ?? "") ?? 0) & 1 == 1)
        case "VERTEX":
            open?.points.append(point(body, 10, 20))
        case "SEQEND":
            if let done = open { drawing.polylines.append(done) }
            open = nil
        case "CIRCLE":
            drawing.rounds.append(Round(layer: layer, center: point(body, 10, 20), radius: number(body, 40) ?? 0, start: nil, end: nil))
        case "ARC":
            drawing.rounds.append(Round(layer: layer, center: point(body, 10, 20), radius: number(body, 40) ?? 0, start: number(body, 50) ?? 0, end: number(body, 51) ?? 0))
        default:
            let raw = body.filter { $0.code == 3 }.map(\.value).joined() + (body.first { $0.code == 1 }?.value ?? "")
            let clean = raw.replacingOccurrences(of: "\\P", with: "\n").replacingOccurrences(of: "\\\\[A-Za-z][^;]*;", with: "", options: .regularExpression)
            drawing.captions.append(Caption(layer: layer, text: clean, at: point(body, 10, 20), height: number(body, 40) ?? 0))
        }
    }
}
