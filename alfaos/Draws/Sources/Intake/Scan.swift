import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import Vision

enum Ocr {
    static let languages = ["de-DE", "en-US"]

    static func read(_ image: CGImage, _ orientation: CGImagePropertyOrientation = .up) throws -> [Span] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = languages
        request.usesLanguageCorrection = true
        try VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:]).perform([request])
        let turned = orientation.rawValue >= 5
        let w = Double(turned ? image.height : image.width), h = Double(turned ? image.width : image.height)
        return (request.results ?? []).compactMap { seen in
            guard let top = seen.topCandidates(1).first else { return nil }
            let text = top.string.trimmingCharacters(in: .whitespacesAndNewlines)
            let b = seen.boundingBox
            return text.isEmpty ? nil : Span(text: text, rect: CGRect(x: b.minX * w, y: (1 - b.maxY) * h, width: b.width * w, height: b.height * h))
        }
    }
}

enum Pict {
    static func read(_ data: Data, _ r: inout Ingested) throws {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw Failure.damaged(r.kind) }
        let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let orientation = (props?[kCGImagePropertyOrientation] as? UInt32).flatMap(CGImagePropertyOrientation.init) ?? .up
        r.images = [Raster(data: data, width: image.width, height: image.height)]
        let turned = orientation.rawValue >= 5
        let size = CGSize(width: turned ? image.height : image.width, height: turned ? image.width : image.height)
        let spans = try Ocr.read(image, orientation)
        if spans.isEmpty { r.note("ocr.empty") }
        r.text = spans.map(\.text).joined(separator: "\n")
        r.pages = [Leaf(index: 0, size: size, text: r.text, runs: spans)]
    }
}

enum Pdf {
    static let dpi = 216.0
    static let side = 4096.0

    static func read(_ data: Data, _ r: inout Ingested) throws {
        guard let doc = PDFDocument(data: data) else { throw Failure.damaged(.pdf) }
        if doc.isLocked && !doc.unlock(withPassword: "") { r.note("pdf.locked"); return }
        for index in 0..<doc.pageCount {
            try Task.checkCancellation()
            guard let page = doc.page(at: index) else { continue }
            let box = page.bounds(for: .cropBox)
            var leaf = Leaf(index: index, size: box.size, text: "", runs: layer(page, box))
            if leaf.runs.isEmpty {
                leaf.runs = try scan(page, box, &r)
            }
            leaf.text = leaf.runs.map(\.text).joined(separator: "\n")
            r.pages.append(leaf)
        }
        r.text = r.pages.map(\.text).filter { !$0.isEmpty }.joined(separator: "\n")
    }

    static func layer(_ page: PDFPage, _ box: CGRect) -> [Span] {
        (page.selection(for: box)?.selectionsByLine() ?? []).compactMap { line in
            let text = (line.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let b = line.bounds(for: page)
            return text.isEmpty ? nil : Span(text: text, rect: CGRect(x: b.minX - box.minX, y: box.maxY - b.maxY, width: b.width, height: b.height))
        }
    }

    static func scan(_ page: PDFPage, _ box: CGRect, _ r: inout Ingested) throws -> [Span] {
        let k = min(dpi / 72, side / max(box.width, box.height, 1))
        let w = max(1, Int((box.width * k).rounded(.up))), h = max(1, Int((box.height * k).rounded(.up)))
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { r.note("ocr.render"); return [] }
        ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.scaleBy(x: k, y: k)
        page.draw(with: .cropBox, to: ctx)
        guard let image = ctx.makeImage() else { r.note("ocr.render"); return [] }
        let spans = try Ocr.read(image).map { Span(text: $0.text, rect: CGRect(x: $0.rect.minX / k, y: $0.rect.minY / k, width: $0.rect.width / k, height: $0.rect.height / k)) }
        r.note(spans.isEmpty ? "ocr.empty" : "ocr.scan")
        return spans
    }
}
