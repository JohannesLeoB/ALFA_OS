import Foundation

public enum SymbolCommand: Equatable, Sendable {
    case move(x: Double, y: Double)
    case line(x: Double, y: Double)
    case curve(x1: Double, y1: Double, x2: Double, y2: Double, x: Double, y: Double)
    case close
}

public enum SymbolPath {
    public static func parse(_ text: String) -> [SymbolCommand] {
        var reader = Reader(Array(text.unicodeScalars))
        var out: [SymbolCommand] = []
        var command: Character?
        var cx = 0.0, cy = 0.0, sx = 0.0, sy = 0.0
        while !reader.atEnd {
            if let next = reader.command() {
                command = next
                if next == "Z" || next == "z" {
                    out.append(.close)
                    cx = sx
                    cy = sy
                    continue
                }
            }
            guard let current = command else { break }
            let relative = current.isLowercase
            let ox = relative ? cx : 0
            let oy = relative ? cy : 0
            switch current {
            case "M", "m":
                guard let x = reader.number(), let y = reader.number() else { return out }
                cx = ox + x
                cy = oy + y
                sx = cx
                sy = cy
                out.append(.move(x: cx, y: cy))
                command = relative ? "l" : "L"
            case "L", "l":
                guard let x = reader.number(), let y = reader.number() else { return out }
                cx = ox + x
                cy = oy + y
                out.append(.line(x: cx, y: cy))
            case "H", "h":
                guard let x = reader.number() else { return out }
                cx = ox + x
                out.append(.line(x: cx, y: cy))
            case "V", "v":
                guard let y = reader.number() else { return out }
                cy = oy + y
                out.append(.line(x: cx, y: cy))
            case "C", "c":
                guard let a = reader.number(), let b = reader.number(), let c = reader.number(),
                      let d = reader.number(), let x = reader.number(), let y = reader.number() else { return out }
                out.append(.curve(x1: ox + a, y1: oy + b, x2: ox + c, y2: oy + d, x: ox + x, y: oy + y))
                cx = ox + x
                cy = oy + y
            case "A", "a":
                guard let rx = reader.number(), let ry = reader.number(), let turn = reader.number(),
                      let large = reader.flag(), let sweep = reader.flag(),
                      let x = reader.number(), let y = reader.number() else { return out }
                out += arc(fromX: cx, fromY: cy, rx: rx, ry: ry, turn: turn, large: large, sweep: sweep,
                           toX: ox + x, toY: oy + y)
                cx = ox + x
                cy = oy + y
            default:
                return out
            }
        }
        return out
    }

    private static func arc(fromX x0: Double, fromY y0: Double, rx radiusX: Double, ry radiusY: Double, turn: Double,
                            large: Bool, sweep: Bool, toX x: Double, toY y: Double) -> [SymbolCommand] {
        var rx = abs(radiusX)
        var ry = abs(radiusY)
        if rx == 0 || ry == 0 || (x0 == x && y0 == y) { return [.line(x: x, y: y)] }
        let phi = turn * .pi / 180
        let cosPhi = cos(phi), sinPhi = sin(phi)
        let dx = (x0 - x) / 2, dy = (y0 - y) / 2
        let x1 = cosPhi * dx + sinPhi * dy
        let y1 = -sinPhi * dx + cosPhi * dy
        let scale = x1 * x1 / (rx * rx) + y1 * y1 / (ry * ry)
        if scale > 1 {
            rx *= scale.squareRoot()
            ry *= scale.squareRoot()
        }
        let numerator = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
        let denominator = rx * rx * y1 * y1 + ry * ry * x1 * x1
        let factor = (large == sweep ? -1.0 : 1.0) * (max(0, numerator) / denominator).squareRoot()
        let cxp = factor * rx * y1 / ry
        let cyp = -factor * ry * x1 / rx
        let cx = cosPhi * cxp - sinPhi * cyp + (x0 + x) / 2
        let cy = sinPhi * cxp + cosPhi * cyp + (y0 + y) / 2
        let ux = (x1 - cxp) / rx, uy = (y1 - cyp) / ry
        let vx = (-x1 - cxp) / rx, vy = (-y1 - cyp) / ry
        let start = atan2(uy, ux)
        var span = atan2(ux * vy - uy * vx, ux * vx + uy * vy)
        if !sweep && span > 0 { span -= 2 * .pi }
        if sweep && span < 0 { span += 2 * .pi }
        let count = max(1, Int((abs(span) / (.pi / 2)).rounded(.up)))
        let step = span / Double(count)
        let k = 4.0 / 3.0 * tan(step / 4)
        func point(_ px: Double, _ py: Double) -> (Double, Double) {
            (cx + rx * px * cosPhi - ry * py * sinPhi, cy + rx * px * sinPhi + ry * py * cosPhi)
        }
        var out: [SymbolCommand] = []
        for index in 0..<count {
            let a = start + step * Double(index)
            let b = a + step
            let p1 = point(cos(a) - k * sin(a), sin(a) + k * cos(a))
            let p2 = point(cos(b) + k * sin(b), sin(b) - k * cos(b))
            let p3 = index == count - 1 ? (x, y) : point(cos(b), sin(b))
            out.append(.curve(x1: p1.0, y1: p1.1, x2: p2.0, y2: p2.1, x: p3.0, y: p3.1))
        }
        return out
    }

    private struct Reader {
        let scalars: [Unicode.Scalar]
        var index = 0

        init(_ scalars: [Unicode.Scalar]) { self.scalars = scalars }

        var atEnd: Bool {
            var probe = index
            while probe < scalars.count, Self.isSeparator(scalars[probe]) { probe += 1 }
            return probe >= scalars.count
        }

        static func isSeparator(_ scalar: Unicode.Scalar) -> Bool {
            scalar == "," || scalar == " " || scalar == "\n" || scalar == "\t"
        }

        mutating func skip() {
            while index < scalars.count, Self.isSeparator(scalars[index]) { index += 1 }
        }

        mutating func command() -> Character? {
            skip()
            guard index < scalars.count else { return nil }
            let scalar = scalars[index]
            guard scalar.properties.isAlphabetic else { return nil }
            index += 1
            return Character(scalar)
        }

        mutating func flag() -> Bool? {
            skip()
            guard index < scalars.count else { return nil }
            let scalar = scalars[index]
            guard scalar == "0" || scalar == "1" else { return nil }
            index += 1
            return scalar == "1"
        }

        mutating func number() -> Double? {
            skip()
            var text = ""
            var seenDot = false
            var seenDigit = false
            while index < scalars.count {
                let scalar = scalars[index]
                if scalar == "-" || scalar == "+" {
                    if !text.isEmpty { break }
                } else if scalar == "." {
                    if seenDot { break }
                    seenDot = true
                } else if scalar.value >= 48 && scalar.value <= 57 {
                    seenDigit = true
                } else {
                    break
                }
                text.unicodeScalars.append(scalar)
                index += 1
            }
            return seenDigit ? Double(text) : nil
        }
    }
}

public enum SymbolName: String, CaseIterable, Sendable {
    case person, building, plug, system, contrast, folder, list, key, docText, doc
    case close, grid, fan, lock, chevron, alert, check, link

    public var path: String {
        switch self {
        case .person: "M8 7.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5ZM3 13.5c.5-2.75 2.5-4 5-4s4.5 1.25 5 4"
        case .building: "M3.5 13.5V2.5h6v11M9.5 6.5h3v7M2.5 13.5h11M5.5 5h2M5.5 8h2M5.5 11h2"
        case .plug: "M5.5 2.5v3M10.5 2.5v3M4 5.5h8v2.5a4 4 0 0 1-8 0ZM8 12v1.5"
        case .system: "M8 10a2 2 0 1 0 0-4 2 2 0 0 0 0 4ZM8 1.5v2M8 12.5v2M1.5 8h2M12.5 8h2M3.4 3.4l1.4 1.4M11.2 11.2l1.4 1.4M3.4 12.6l1.4-1.4M11.2 4.8l1.4-1.4"
        case .contrast: "M8 13.5a5.5 5.5 0 1 0 0-11 5.5 5.5 0 0 0 0 11ZM8 2.5v11"
        case .folder: "M2.5 4.5h4l1.5 1.5h5.5v6.5h-11Z"
        case .list: "M6 4.5h7.5M6 8h7.5M6 11.5h7.5M2.5 4.5h1M2.5 8h1M2.5 11.5h1"
        case .key: "M5.5 10.5a3 3 0 1 0 0-6 3 3 0 0 0 0 6ZM8.5 7.5h5v2M11.5 7.5v2"
        case .docText: "M4 2h5l3 3v9H4ZM9 2v3h3M6.5 8h3M6.5 10.5h3"
        case .doc: "M4 2h5l3 3v9H4ZM9 2v3h3"
        case .close: "M4.5 4.5l7 7M11.5 4.5l-7 7"
        case .grid: "M2.5 2.5h4.5v4.5h-4.5ZM9 2.5h4.5v4.5H9ZM2.5 9h4.5v4.5h-4.5ZM9 9h4.5v4.5H9Z"
        case .fan: "M4.5 5.5h7v8h-7ZM5.5 3.5h5M6.5 1.5h3"
        case .lock: "M4.5 7.5h7v6h-7ZM6 7.5V5.5a2 2 0 0 1 4 0v2"
        case .chevron: "M4.5 6.5L8 10l3.5-3.5"
        case .alert: "M8 2.5l6 11H2ZM8 6.5v3M8 11.5v.25"
        case .check: "M3.5 8.5l3 3 6-7"
        case .link: "M7 9a2.5 2.5 0 0 0 3.5 0l2-2A2.5 2.5 0 0 0 9 3.5l-.7.7M9 7a2.5 2.5 0 0 0-3.5 0l-2 2A2.5 2.5 0 0 0 7 12.5l.7-.7"
        }
    }

    public var commands: [SymbolCommand] { SymbolPath.parse(path) }
}
