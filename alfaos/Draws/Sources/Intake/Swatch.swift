import CoreGraphics
import Foundation
import ImageIO
import PDFKit

enum Swatch {
    static let box = 32.0
    static let apart = 48
    static let alpha = 128

    static func hex(_ c: (Int, Int, Int)) -> String {
        String(format: "#%02x%02x%02x", c.0, c.1, c.2)
    }

    static func near(_ a: (Int, Int, Int), _ b: (Int, Int, Int)) -> Bool {
        let d = (a.0 - b.0) * (a.0 - b.0) + (a.1 - b.1) * (a.1 - b.1) + (a.2 - b.2) * (a.2 - b.2)
        return d < apart * apart
    }

    static func colours(_ image: CGImage, _ count: Int) -> [String] {
        let k = min(1, box / Double(max(image.width, image.height, 1)))
        let w = max(1, Int((Double(image.width) * k).rounded())), h = max(1, Int((Double(image.height) * k).rounded()))
        guard count > 0, let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let raw = ctx.data else { return [] }
        ctx.interpolationQuality = .medium
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        let px = raw.bindMemory(to: UInt8.self, capacity: w * h * 4)
        var sums: [Int: (n: Int, r: Int, g: Int, b: Int)] = [:]
        for i in 0..<(w * h) {
            let a = Int(px[i * 4 + 3])
            guard a >= alpha else { continue }
            let r = min(255, Int(px[i * 4]) * 255 / a), g = min(255, Int(px[i * 4 + 1]) * 255 / a), b = min(255, Int(px[i * 4 + 2]) * 255 / a)
            let key = (r >> 4) << 8 | (g >> 4) << 4 | (b >> 4)
            let old = sums[key] ?? (0, 0, 0, 0)
            sums[key] = (old.n + 1, old.r + r, old.g + g, old.b + b)
        }
        let ranked = sums.sorted { $0.value.n != $1.value.n ? $0.value.n > $1.value.n : $0.key < $1.key }
        var picked: [(Int, Int, Int)] = []
        for (_, v) in ranked {
            let c = (v.r / v.n, v.g / v.n, v.b / v.n)
            if picked.contains(where: { near($0, c) }) { continue }
            picked.append(c)
            if picked.count == count { break }
        }
        return picked.map(hex)
    }

    static func page(_ data: Data, _ index: Int, _ side: Double) -> CGImage? {
        guard let doc = PDFDocument(data: data), !doc.isLocked || doc.unlock(withPassword: ""),
              let page = doc.page(at: index) else { return nil }
        let box = page.bounds(for: .cropBox)
        let k = side / max(box.width, box.height, 1)
        let w = max(1, Int((box.width * k).rounded(.up))), h = max(1, Int((box.height * k).rounded(.up)))
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.scaleBy(x: k, y: k)
        page.draw(with: .cropBox, to: ctx)
        return ctx.makeImage()
    }
}

public func palette(of data: Data, count: Int) -> [String] {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return [] }
    return Swatch.colours(image, count)
}

public func palettes(ofPDF data: Data, count: Int, pages: Int) -> [[String]] {
    let total = PDFDocument(data: data)?.pageCount ?? 0
    return (0..<min(total, max(0, pages))).map { index in
        Swatch.page(data, index, Swatch.box * 4).map { Swatch.colours($0, count) } ?? []
    }
}

public func raster(ofPDF data: Data, page: Int, side: Int) -> Data? {
    guard let image = Swatch.page(data, page, Double(side)) else { return nil }
    let out = NSMutableData()
    guard let target = CGImageDestinationCreateWithData(out as CFMutableData, "public.png" as CFString, 1, nil) else { return nil }
    CGImageDestinationAddImage(target, image, nil)
    return CGImageDestinationFinalize(target) ? out as Data : nil
}
