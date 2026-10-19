import Foundation

public enum Icon: String, CaseIterable, Sendable {
    case search, filter, compose, inbox, flag, sent, allMail, archive, junk, trash
    case reply, replyAll, forward, fan, send, close, pin, more, grid, print
    case export, attach, folder, person, personAdd, people, bold, italic, underline, list
    case numbered, link, textSize, save, expand, shrink, minus, check, docText, chevron
    case lock, envelope, doc, alert, tick, building, plug, system, contrast, key
    case tag

    public var data: String {
        switch self {
        case .search: "M7 12.5a5.5 5.5 0 1 0 0-11 5.5 5.5 0 0 0 0 11ZM11 11l3.5 3.5"
        case .filter: "M2.5 3.5h11l-4.25 5v4.5l-2.5-1.25V8.5Z"
        case .compose: "M11 2.5l2.5 2.5L6 12.5H3.5V10ZM9.5 4l2.5 2.5"
        case .inbox: "M2.5 9.5l1.5-6h8l1.5 6v3.5h-11ZM2.5 9.5h3l1 1.5h3l1-1.5h3"
        case .flag: "M4 14V2.5M4 3h7.5l-1.5 2.75L11.5 8.5H4"
        case .sent: "M14 2L7 9M14 2l-4.5 12-2.5-5-5-2.5Z"
        case .allMail: "M2.5 6.5h11v6h-11ZM4 4.5h8M5.5 2.5h5"
        case .archive: "M2.5 3.5h11v3h-11ZM3.5 6.5v6h9v-6M6.5 9h3"
        case .junk: "M5.5 2.5h5l3 3v5l-3 3h-5l-3-3v-5ZM8 5.5v3M8 10.75v.5"
        case .trash: "M3 4.5h10M6.5 4.5V3h3v1.5M4.5 4.5l.7 9h5.6l.7-9"
        case .reply: "M6.5 4L2.5 8l4 4M2.5 8h7a4 4 0 0 1 4 4v.5"
        case .replyAll: "M9 4L5 8l4 4M5 8h4.5a4 4 0 0 1 4 4v.5M5.5 4l-4 4 4 4"
        case .forward: "M9.5 4l4 4-4 4M13.5 8h-7a4 4 0 0 0-4 4v.5"
        case .fan: "M4.5 5.5h7v8h-7ZM5.5 3.5h5M6.5 1.5h3"
        case .send: "M8 13V3.5M4 7.5l4-4 4 4"
        case .close: "M4.5 4.5l7 7M11.5 4.5l-7 7"
        case .pin: "M8 10.5V14.5M5 10.5h6M5.75 10.5l.75-5h3l.75 5M6 2.5h4"
        case .more: "M5 8a1 1 0 1 1-2 0 1 1 0 0 1 2 0ZM9 8a1 1 0 1 1-2 0 1 1 0 0 1 2 0ZM13 8a1 1 0 1 1-2 0 1 1 0 0 1 2 0Z"
        case .grid: "M2.5 2.5h4.5v4.5h-4.5ZM9 2.5h4.5v4.5H9ZM2.5 9h4.5v4.5h-4.5ZM9 9h4.5v4.5H9Z"
        case .print: "M4.5 5.5v-3h7v3M4.5 11.5h-2v-5h11v5h-2M4.5 9h7v4.5h-7Z"
        case .export: "M8 2.5V10M4.5 6.5L8 10l3.5-3.5M3 13h10"
        case .attach: "M12.5 7.5l-4.75 4.75a3 3 0 0 1-4.25-4.25L8.5 3a2 2 0 0 1 2.83 2.83L6.5 10.66a1 1 0 0 1-1.41-1.41L9.5 4.83"
        case .folder: "M2.5 4.5h4l1.5 1.5h5.5v6.5h-11Z"
        case .person: "M8 7.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5ZM3 13.5c.5-2.75 2.5-4 5-4s4.5 1.25 5 4"
        case .personAdd: "M6.5 7.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5ZM2 13.5c.5-2.5 2.25-3.75 4.5-3.75s4 1.25 4.5 3.75M12.5 4.5v4M10.5 6.5h4"
        case .people: "M6 7a2 2 0 1 0 0-4 2 2 0 0 0 0 4ZM2.5 12.5c.4-2 1.75-3 3.5-3s3.1 1 3.5 3M10.5 7a2 2 0 1 0 0-4M11.5 9.6c1.2.3 2 1.2 2.25 2.9"
        case .bold: "M5 3h3.5a2.5 2.5 0 0 1 0 5H5ZM5 8h4a2.5 2.5 0 0 1 0 5H5Z"
        case .italic: "M7 3h5M4 13h5M10 3L6 13"
        case .underline: "M4.5 2.5v5a3.5 3.5 0 0 0 7 0v-5M3.5 13.5h9"
        case .list: "M6 4.5h7.5M6 8h7.5M6 11.5h7.5M2.5 4.5h1M2.5 8h1M2.5 11.5h1"
        case .numbered: "M6.5 4.5h7M6.5 8h7M6.5 11.5h7M2.5 3.5l1-.5v3"
        case .link: "M7 9a2.5 2.5 0 0 0 3.5 0l2-2A2.5 2.5 0 0 0 9 3.5l-.7.7M9 7a2.5 2.5 0 0 0-3.5 0l-2 2A2.5 2.5 0 0 0 7 12.5l.7-.7"
        case .textSize: "M2 12.5l3-8 3 8M3 10h4M10.5 12.5V9.5a1.75 1.75 0 0 1 3.5 0v3M10.5 11h3.5"
        case .save: "M8 2.5v7M5 6.5l3 3 3-3M2.5 10.5v3h11v-3"
        case .expand: "M9.5 2.5h4v4M6.5 13.5h-4v-4M13.5 2.5L9 7M2.5 13.5L7 9"
        case .shrink: "M13.5 2.5L10 6M10 3v3h3M2.5 13.5L6 10M6 13v-3H3"
        case .minus: "M4 8h8"
        case .check: "M3.5 8.5l3 3 6-7"
        case .docText: "M4 2h5l3 3v9H4ZM9 2v3h3M6.5 8h3M6.5 10.5h3"
        case .chevron: "M4.5 6.5L8 10l3.5-3.5"
        case .lock: "M4.5 7.5h7v6h-7ZM6 7.5V5.5a2 2 0 0 1 4 0v2"
        case .envelope: "M2.5 4h11v8h-11ZM2.5 4.5L8 9l5.5-4.5"
        case .doc: "M4 2h5l3 3v9H4ZM9 2v3h3"
        case .alert: "M8 2.5l6 11H2ZM8 6.5v3M8 11.5v.25"
        case .tick: "M3 8.5l3.2 3.2L13 4.8"
        case .building: "M3.5 13.5V2.5h6v11M9.5 6.5h3v7M2.5 13.5h11M5.5 5h2M5.5 8h2M5.5 11h2"
        case .plug: "M5.5 2.5v3M10.5 2.5v3M4 5.5h8v2.5a4 4 0 0 1-8 0ZM8 12v1.5"
        case .system: "M8 10a2 2 0 1 0 0-4 2 2 0 0 0 0 4ZM8 1.5v2M8 12.5v2M1.5 8h2M12.5 8h2M3.4 3.4l1.4 1.4M11.2 11.2l1.4 1.4M3.4 12.6l1.4-1.4M11.2 4.8l1.4-1.4"
        case .contrast: "M8 13.5a5.5 5.5 0 1 0 0-11 5.5 5.5 0 0 0 0 11ZM8 2.5v11"
        case .key: "M5.5 10.5a3 3 0 1 0 0-6 3 3 0 0 0 0 6ZM8.5 7.5h5v2M11.5 7.5v2"
        case .tag: "M2.5 2.5h5.5l5.5 5.5-5.5 5.5-5.5-5.5ZM5.5 5.25v.5"
        }
    }

    public var path: IconPath { Self.paths[self] ?? IconPath(segments: []) }

    private static let paths: [Icon: IconPath] = Dictionary(uniqueKeysWithValues: allCases.map { ($0, IconPath(data: $0.data)) })
}

public struct IconPath: Equatable, Sendable {
    public enum Segment: Equatable, Sendable {
        case move(x: Double, y: Double)
        case line(x: Double, y: Double)
        case cubic(c1x: Double, c1y: Double, c2x: Double, c2y: Double, x: Double, y: Double)
        case close
    }

    public let segments: [Segment]

    public init(segments: [Segment]) {
        self.segments = segments
    }

    public init(data: String) {
        var reader = IconReader(Array(data))
        var builder = IconBuilder()
        while let command = reader.command() {
            builder.run(command, &reader)
        }
        segments = builder.segments
    }
}

private struct IconReader {
    let chars: [Character]
    var index = 0

    init(_ chars: [Character]) {
        self.chars = chars
    }

    mutating func skip() {
        while index < chars.count, chars[index] == " " || chars[index] == "," || chars[index] == "\n" { index += 1 }
    }

    mutating func command() -> Character? {
        skip()
        guard index < chars.count, chars[index].isLetter else { return nil }
        defer { index += 1 }
        return chars[index]
    }

    mutating func hasNumber() -> Bool {
        skip()
        guard index < chars.count else { return false }
        let c = chars[index]
        return c == "-" || c == "+" || c == "." || c.isASCII && c.isNumber
    }

    mutating func number() -> Double {
        skip()
        var text = ""
        if index < chars.count, chars[index] == "-" || chars[index] == "+" {
            text.append(chars[index])
            index += 1
        }
        var dot = false
        while index < chars.count {
            let c = chars[index]
            if c.isASCII && c.isNumber {
                text.append(c)
            } else if c == ".", !dot {
                dot = true
                text.append(c)
            } else {
                break
            }
            index += 1
        }
        return Double(text) ?? 0
    }

    mutating func flag() -> Bool {
        skip()
        guard index < chars.count else { return false }
        defer { index += 1 }
        return chars[index] == "1"
    }
}

private struct IconBuilder {
    var segments: [IconPath.Segment] = []
    var x = 0.0
    var y = 0.0
    var startX = 0.0
    var startY = 0.0
    var lastC2x = 0.0
    var lastC2y = 0.0
    var smooth = false

    mutating func run(_ command: Character, _ r: inout IconReader) {
        let relative = command.isLowercase
        let kind = Character(command.uppercased())
        if kind == "Z" {
            segments.append(.close)
            x = startX
            y = startY
            smooth = false
            return
        }
        var first = true
        repeat {
            let ox = relative ? x : 0
            let oy = relative ? y : 0
            switch kind {
            case "M":
                let nx = r.number() + ox, ny = r.number() + oy
                if first {
                    segments.append(.move(x: nx, y: ny))
                    startX = nx
                    startY = ny
                } else {
                    segments.append(.line(x: nx, y: ny))
                }
                x = nx
                y = ny
                smooth = false
            case "L":
                let nx = r.number() + ox, ny = r.number() + oy
                segments.append(.line(x: nx, y: ny))
                x = nx
                y = ny
                smooth = false
            case "H":
                let nx = r.number() + ox
                segments.append(.line(x: nx, y: y))
                x = nx
                smooth = false
            case "V":
                let ny = r.number() + oy
                segments.append(.line(x: x, y: ny))
                y = ny
                smooth = false
            case "C":
                let c1x = r.number() + ox, c1y = r.number() + oy
                let c2x = r.number() + ox, c2y = r.number() + oy
                let nx = r.number() + ox, ny = r.number() + oy
                cubic(c1x, c1y, c2x, c2y, nx, ny)
            case "S":
                let c1x = smooth ? 2 * x - lastC2x : x
                let c1y = smooth ? 2 * y - lastC2y : y
                let c2x = r.number() + ox, c2y = r.number() + oy
                let nx = r.number() + ox, ny = r.number() + oy
                cubic(c1x, c1y, c2x, c2y, nx, ny)
            case "A":
                let rx = r.number(), ry = r.number(), turn = r.number()
                let large = r.flag(), sweep = r.flag()
                let nx = r.number() + ox, ny = r.number() + oy
                arc(rx, ry, turn, large, sweep, nx, ny)
            default:
                return
            }
            first = false
        } while r.hasNumber()
    }

    mutating func cubic(_ c1x: Double, _ c1y: Double, _ c2x: Double, _ c2y: Double, _ nx: Double, _ ny: Double) {
        segments.append(.cubic(c1x: c1x, c1y: c1y, c2x: c2x, c2y: c2y, x: nx, y: ny))
        lastC2x = c2x
        lastC2y = c2y
        x = nx
        y = ny
        smooth = true
    }

    mutating func arc(_ rxIn: Double, _ ryIn: Double, _ turn: Double, _ large: Bool, _ sweep: Bool, _ nx: Double, _ ny: Double) {
        var rx = abs(rxIn), ry = abs(ryIn)
        smooth = false
        if rx == 0 || ry == 0 || (nx == x && ny == y) {
            segments.append(.line(x: nx, y: ny))
            x = nx
            y = ny
            return
        }
        let phi = turn * .pi / 180
        let cosP = cos(phi), sinP = sin(phi)
        let dx = (x - nx) / 2, dy = (y - ny) / 2
        let x1 = cosP * dx + sinP * dy
        let y1 = -sinP * dx + cosP * dy
        let lambda = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
        if lambda > 1 {
            let root = lambda.squareRoot()
            rx *= root
            ry *= root
        }
        let sign: Double = large == sweep ? -1 : 1
        let numerator = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
        let denominator = rx * rx * y1 * y1 + ry * ry * x1 * x1
        let factor = sign * max(0, numerator / denominator).squareRoot()
        let cxp = factor * rx * y1 / ry
        let cyp = -factor * ry * x1 / rx
        let cx = cosP * cxp - sinP * cyp + (x + nx) / 2
        let cy = sinP * cxp + cosP * cyp + (y + ny) / 2
        let start = atan2((y1 - cyp) / ry, (x1 - cxp) / rx)
        var delta = atan2((-y1 - cyp) / ry, (-x1 - cxp) / rx) - start
        if sweep, delta < 0 { delta += 2 * .pi }
        if !sweep, delta > 0 { delta -= 2 * .pi }
        let parts = max(1, Int((abs(delta) / (.pi / 2)).rounded(.up)))
        let step = delta / Double(parts)
        let k = 4.0 / 3.0 * tan(step / 4)
        var angle = start
        for part in 0..<parts {
            let next = angle + step
            let from = Ellipse(cx: cx, cy: cy, rx: rx, ry: ry, cosP: cosP, sinP: sinP, angle: angle)
            let to = Ellipse(cx: cx, cy: cy, rx: rx, ry: ry, cosP: cosP, sinP: sinP, angle: next)
            let last = part == parts - 1
            segments.append(.cubic(c1x: from.x + k * from.dx, c1y: from.y + k * from.dy,
                                   c2x: to.x - k * to.dx, c2y: to.y - k * to.dy,
                                   x: last ? nx : to.x, y: last ? ny : to.y))
            angle = next
        }
        x = nx
        y = ny
    }
}

private struct Ellipse {
    let x: Double
    let y: Double
    let dx: Double
    let dy: Double

    init(cx: Double, cy: Double, rx: Double, ry: Double, cosP: Double, sinP: Double, angle: Double) {
        let px = rx * cos(angle), py = ry * sin(angle)
        x = cosP * px - sinP * py + cx
        y = sinP * px + cosP * py + cy
        let tx = -rx * sin(angle), ty = ry * cos(angle)
        dx = cosP * tx - sinP * ty
        dy = sinP * tx + cosP * ty
    }
}
