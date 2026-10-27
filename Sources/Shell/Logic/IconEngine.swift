import Foundation

enum IconEngine {
    static func segments(data: String) -> [IconPath.Segment] {
        var reader = IconReader(Array(data))
        var builder = IconBuilder()
        while let command = reader.command() {
            builder.run(command, &reader)
        }
        return builder.segments
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
            let from = IconEllipse(cx: cx, cy: cy, rx: rx, ry: ry, cosP: cosP, sinP: sinP, angle: angle)
            let to = IconEllipse(cx: cx, cy: cy, rx: rx, ry: ry, cosP: cosP, sinP: sinP, angle: next)
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

private struct IconEllipse {
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
