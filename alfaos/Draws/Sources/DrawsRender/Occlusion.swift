import AppKit
import Foundation

enum Occlusion {
    static let levels = 6
    static let step = 255 / (levels - 1)
    static let capacity = levels * levels * levels - 1
    static let jointReach = 0.0035
    static let contactReach = 0.008
    static let jointDark = 0.5
    static let contactDark = 0.2

    static func color(_ index: Int) -> NSColor {
        let r = index / (levels * levels), g = index / levels % levels, b = index % levels
        return NSColor(srgbRed: CGFloat(r * step) / 255, green: CGFloat(g * step) / 255, blue: CGFloat(b * step) / 255, alpha: 1)
    }

    static func decode(_ bytes: [UInt8], count: Int) -> [Int16] {
        var out = [Int16](repeating: 0, count: count)
        let half = step / 2
        for i in 0..<count {
            let b = (Int(bytes[i * 4]) + half) / step, g = (Int(bytes[i * 4 + 1]) + half) / step, r = (Int(bytes[i * 4 + 2]) + half) / step
            out[i] = Int16(r * levels * levels + g * levels + b)
        }
        return out
    }

    static func distance(_ seed: [Bool], width w: Int, height h: Int) -> [Float] {
        let far = Float(w + h)
        var d = seed.map { $0 ? Float(0) : far }
        let diagonal: Float = 1.4142
        for y in 0..<h {
            for x in 0..<w {
                let i = y * w + x
                var v = d[i]
                if x > 0 { v = min(v, d[i - 1] + 1) }
                if y > 0 {
                    v = min(v, d[i - w] + 1)
                    if x > 0 { v = min(v, d[i - w - 1] + diagonal) }
                    if x < w - 1 { v = min(v, d[i - w + 1] + diagonal) }
                }
                d[i] = v
            }
        }
        for y in stride(from: h - 1, through: 0, by: -1) {
            for x in stride(from: w - 1, through: 0, by: -1) {
                let i = y * w + x
                var v = d[i]
                if x < w - 1 { v = min(v, d[i + 1] + 1) }
                if y < h - 1 {
                    v = min(v, d[i + w] + 1)
                    if x < w - 1 { v = min(v, d[i + w + 1] + diagonal) }
                    if x > 0 { v = min(v, d[i + w - 1] + diagonal) }
                }
                d[i] = v
            }
        }
        return d
    }

    static func apply(_ lit: inout [UInt8], ids idBytes: [UInt8], width w: Int, height h: Int) {
        let ids = decode(idBytes, count: w * h)
        var joint = [Bool](repeating: false, count: w * h), contact = joint
        func mark(_ i: Int, _ j: Int) {
            let a = ids[i], b = ids[j]
            guard a != b else { return }
            if a != 0, b != 0 { joint[i] = true; joint[j] = true } else if a == 0 { contact[i] = true } else { contact[j] = true }
        }
        for y in 0..<h {
            for x in 0..<w {
                let i = y * w + x
                if x < w - 1 { mark(i, i + 1) }
                if y < h - 1 { mark(i, i + w) }
            }
        }
        let rj = Float(Double(w) * jointReach), rc = Float(Double(w) * contactReach)
        let dj = distance(joint, width: w, height: h), dc = distance(contact, width: w, height: h)
        for i in 0..<(w * h) {
            let fj = max(0, 1 - dj[i] / rj), fc = ids[i] == 0 ? max(0, 1 - dc[i] / rc) : 0
            let dark = max(Float(jointDark) * fj * fj, Float(contactDark) * fc * fc)
            guard dark > 0 else { continue }
            let k = 1 - dark
            for c in 0..<3 { lit[i * 4 + c] = UInt8(Float(lit[i * 4 + c]) * k) }
        }
    }
}
