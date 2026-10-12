import Foundation
import CoreGraphics
import Tokens

/// Color in CIE Lab space (D65). Distances in Lab roughly match what the eye sees.
public struct Lab: Hashable, Sendable {
    public var l: Double, a: Double, b: Double

    public init(l: Double, a: Double, b: Double) {
        self.l = l
        self.a = a
        self.b = b
    }
}

public enum ColorMath {
    static func lin(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
    static func gam(_ c: Double) -> Double { c <= 0.0031308 ? 12.92 * c : 1.055 * pow(c, 1 / 2.4) - 0.055 }

    /// Relative luminance according to WCAG 2.x.
    public static func luminance(_ c: RGB) -> Double { 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b) }
    /// Contrast ratio according to WCAG 2.x: (L1 + 0.05) / (L2 + 0.05). Black on white is 21.
    public static func contrast(_ x: RGB, _ y: RGB) -> Double {
        let a = luminance(x), b = luminance(y); return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
    /// WCAG level for normal text: AAA from 7, AA from 4.5. For large text, AA applies from 3.
    /// Below that, the result is the localized text for "insufficient".
    public static func wcagLevel(_ ratio: Double, largeText: Bool = false) -> String {
        if largeText { return ratio >= 4.5 ? "AAA" : ratio >= 3 ? "AA" : String(localized: "contrast.level.insufficient") }
        return ratio >= 7 ? "AAA" : ratio >= 4.5 ? "AA" : String(localized: "contrast.level.insufficient")
    }

    public static func lab(_ c: RGB) -> Lab {
        let r = lin(c.r), g = lin(c.g), b = lin(c.b)
        let x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
        let y = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 1.0
        let z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
        func f(_ t: Double) -> Double { t > 0.008856 ? cbrt(t) : 7.787 * t + 16.0 / 116 }
        return Lab(l: 116 * f(y) - 16, a: 500 * (f(x) - f(y)), b: 200 * (f(y) - f(z)))
    }
    public static func rgb(_ p: Lab) -> RGB {
        let fy = (p.l + 16) / 116, fx = fy + p.a / 500, fz = fy - p.b / 200
        func inv(_ t: Double) -> Double { let t3 = t * t * t; return t3 > 0.008856 ? t3 : (t - 16.0 / 116) / 7.787 }
        let x = inv(fx) * 0.95047, y = inv(fy), z = inv(fz) * 1.08883
        let r = 3.2406 * x - 1.5372 * y - 0.4986 * z
        let g = -0.9689 * x + 1.8758 * y + 0.0415 * z
        let b = 0.0557 * x - 0.2040 * y + 1.0570 * z
        func c(_ v: Double) -> Double { min(max(gam(v), 0), 1) }
        return RGB(r: c(r), g: c(g), b: c(b))
    }
    /// Color difference ΔE (CIE76). Below about 2.3, the difference is hardly visible.
    public static func deltaE(_ p: Lab, _ q: Lab) -> Double {
        ((p.l - q.l) * (p.l - q.l) + (p.a - q.a) * (p.a - q.a) + (p.b - q.b) * (p.b - q.b)).squareRoot()
    }
}

/// A found color with its share of the image area.
public struct Swatch: Hashable, Sendable { public var color: RGB; public var share: Double }

public enum Palette {
    /// Extracts colors from an image: shrink the image, convert pixels to Lab, k-means with a fixed start choice.
    /// The same image always gives the same palette. Sorted by share.
    public static func extract(from image: CGImage, count k: Int = 6, sample: Int = 64) -> [Swatch] {
        let pixels = rgbPixels(image, side: sample)
        return kMeans(pixels.map(ColorMath.lab), k: k)
    }

    /// Pixels of an image, scaled down to side x side, as sRGB. Transparent pixels are dropped.
    public static func rgbPixels(_ image: CGImage, side: Int) -> [RGB] {
        let w = side, h = side, bpr = w * 4
        var data = [UInt8](repeating: 0, count: h * bpr)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: bpr, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return [] }
        ctx.interpolationQuality = .medium
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        var out: [RGB] = []; out.reserveCapacity(w * h)
        for i in stride(from: 0, to: data.count, by: 4) where data[i + 3] > 127 {
            let a = Double(data[i + 3]) / 255
            out.append(RGB(r: Double(data[i]) / 255 / a, g: Double(data[i + 1]) / 255 / a, b: Double(data[i + 2]) / 255 / a))
        }
        return out
    }

    /// k-means in Lab. Start: the first center is the first point, then each further center is the farthest point.
    public static func kMeans(_ pts: [Lab], k: Int, iterations: Int = 12) -> [Swatch] {
        guard !pts.isEmpty, k > 0 else { return [] }
        var centers: [Lab] = [pts[0]]
        while centers.count < min(k, pts.count) {
            var best = pts[0], bestD = -1.0
            for p in pts { let d = centers.map { ColorMath.deltaE(p, $0) }.min()!; if d > bestD { bestD = d; best = p } }
            if bestD < 1 { break }      // everything is already covered
            centers.append(best)
        }
        var assign = [Int](repeating: 0, count: pts.count)
        for _ in 0..<iterations {
            for (i, p) in pts.enumerated() {
                var bi = 0, bd = Double.infinity
                for (j, c) in centers.enumerated() { let d = ColorMath.deltaE(p, c); if d < bd { bd = d; bi = j } }
                assign[i] = bi
            }
            var sums = [(Double, Double, Double, Int)](repeating: (0, 0, 0, 0), count: centers.count)
            for (i, p) in pts.enumerated() { let a = assign[i]; sums[a].0 += p.l; sums[a].1 += p.a; sums[a].2 += p.b; sums[a].3 += 1 }
            for j in centers.indices where sums[j].3 > 0 {
                let n = Double(sums[j].3); centers[j] = Lab(l: sums[j].0 / n, a: sums[j].1 / n, b: sums[j].2 / n)
            }
        }
        var counts = [Int](repeating: 0, count: centers.count); for a in assign { counts[a] += 1 }
        return centers.indices.filter { counts[$0] > 0 }
            .map { Swatch(color: ColorMath.rgb(centers[$0]), share: Double(counts[$0]) / Double(pts.count)) }
            .sorted { $0.share > $1.share }
    }

    /// Merges similar colors (ΔE below the threshold). The result keeps the color with the largest share.
    public static func unify(_ swatches: [Swatch], threshold: Double = 6) -> [Swatch] {
        var out: [Swatch] = []
        for s in swatches.sorted(by: { $0.share > $1.share }) {
            if let i = out.firstIndex(where: { ColorMath.deltaE(ColorMath.lab($0.color), ColorMath.lab(s.color)) < threshold }) {
                out[i].share += s.share
            } else { out.append(s) }
        }
        return out
    }

    /// Suggested tokens from a palette: color.palette.1 ... n.
    public static func tokens(from swatches: [Swatch], group: String = "palette") -> [Token] {
        swatches.enumerated().map { i, s in
            Token(["color", group, String(i + 1)], .color(s.color), description: String(format: String(localized: "palette.share.format"), s.share * 100))
        }
    }
}
