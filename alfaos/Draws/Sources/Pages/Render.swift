import AppKit
import CoreGraphics
import Foundation
import ImageIO
import PDFKit

public protocol Renderer: Sendable {
    associatedtype Output: Sendable
    func render(_ doc: Document) -> Output
}

public struct PDFRenderer: Renderer {
    static let points = 72 / 25.4

    public init() {}

    public func render(_ doc: Document) -> Data {
        guard !doc.pages.isEmpty else { return Data() }
        let k = PDFRenderer.points
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let ctx = CGContext(consumer: consumer, mediaBox: nil, nil) else { return Data() }
        for page in doc.pages {
            var box = CGRect(x: 0, y: 0, width: page.size.width * k, height: page.size.height * k)
            let info = [kCGPDFContextMediaBox as String: NSData(bytes: &box, length: MemoryLayout<CGRect>.size)] as CFDictionary
            ctx.beginPDFPage(info)
            ctx.translateBy(x: 0, y: box.height)
            ctx.scaleBy(x: k, y: -k)
            Painter.draw(page, fonts: doc.fonts, in: ctx)
            ctx.endPDFPage()
        }
        ctx.closePDF()
        return data as Data
    }
}

public struct BitmapRenderer: Renderer {
    public var dpi: Double

    public init(dpi: Double = 150) {
        self.dpi = dpi
    }

    public func render(_ doc: Document) -> [Data] {
        doc.pages.compactMap { png($0, fonts: doc.fonts) }
    }

    public func png(_ page: Page, fonts: [FontFace]) -> Data? {
        let k = dpi / 25.4
        let w = max(1, Int((page.size.width * k).rounded(.up))), h = max(1, Int((page.size.height * k).rounded(.up)))
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.setFillColor(Tint.cg("white"))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: k, y: -k)
        Painter.draw(page, fonts: fonts, in: ctx)
        guard let image = ctx.makeImage() else { return nil }
        let out = NSMutableData()
        guard let target = CGImageDestinationCreateWithData(out as CFMutableData, "public.png" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(target, image, nil)
        return CGImageDestinationFinalize(target) ? out as Data : nil
    }
}

public enum Printer {
    @MainActor public static func run(_ pdf: Data) -> Bool {
        guard let doc = PDFDocument(data: pdf),
              let operation = doc.printOperation(for: NSPrintInfo.shared, scalingMode: .pageScaleNone, autoRotate: true) else { return false }
        return operation.run()
    }
}
