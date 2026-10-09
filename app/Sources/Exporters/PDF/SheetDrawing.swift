import CoreGraphics
import Foundation
import ALFAcolorCore
import Document

/// Draws the sheet pages into one PDF with Core Graphics. The numbers come from `SheetLayout`, the content from `SheetPages`.
enum SheetDrawing {
    /// Greys of the sheet, as lightness: 0 black, 1 white.
    private enum Grey {
        static let paper = 1.0
        static let ink = 0.12
        static let muted = 0.42
        static let rule = 0.55
        static let placeholder = 0.9
        static let piece = 0.95
    }

    /// The PDF bytes of the pages, one page per entry, on the given paper. Nil when Core Graphics cannot write.
    static func pdf(pages: [SheetPage], paper: SheetPaper, title: String, date: String, labels: SheetLabels) -> Data? {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { return nil }
        var box = CGRect(x: 0, y: 0, width: paper.width, height: paper.height)
        let info = [kCGPDFContextTitle as String: title] as CFDictionary
        guard let context = CGContext(consumer: consumer, mediaBox: &box, info) else { return nil }
        let canvas = SheetCanvas(context: context, height: paper.height)
        for (index, page) in pages.enumerated() {
            context.beginPDFPage(nil)
            draw(page, pageIndex: index + 1, pageCount: pages.count, paper: paper, canvas: canvas,
                 header: Header(title: title, date: date), labels: labels)
            context.endPDFPage()
        }
        context.closePDF()
        return data as Data
    }

    /// The words of the page head that come from the document.
    private struct Header {
        let title: String
        let date: String
    }

    private static func draw(_ page: SheetPage, pageIndex: Int, pageCount: Int, paper: SheetPaper, canvas: SheetCanvas,
                             header: Header, labels: SheetLabels) {
        let m = SheetLayout.Metrics.self
        let layout = SheetLayout.make(paper: paper, frame: page.size, pieces: page.pieces.map(\.rect),
                                      legendEntries: page.legend.count)
        let ink = SheetCanvas.grey(Grey.ink)
        let muted = SheetCanvas.grey(Grey.muted)

        canvas.fill(Rect(x: 0, y: 0, w: paper.width, h: paper.height), SheetCanvas.grey(Grey.paper))

        // Head: frame title and device on the left; document, space and date on the right.
        let title = page.title ?? labels.freeSheet
        canvas.text(title, x: m.margin, baseline: m.margin + 14, size: 14, bold: true, colour: ink)
        let device = page.deviceKey.map { String(localized: String.LocalizationValue($0)) }
        let size = "\(number(page.size.w)) × \(number(page.size.h)) pt"
        canvas.text([device, size].compactMap { $0 }.joined(separator: " · "), x: m.margin, baseline: m.margin + 30,
                    size: 9, colour: muted)
        let room = [header.title, page.space, header.date].filter { !$0.isEmpty }.joined(separator: " · ")
        canvas.text(room, x: paper.width - m.margin, baseline: m.margin + 14, size: 9, colour: muted, align: .trailing)

        // Frame and pieces.
        canvas.fill(layout.frame, SheetCanvas.grey(Grey.paper))
        canvas.stroke(layout.frame, ink, width: 0.75)
        for (piece, box) in zip(page.pieces, layout.pieces) {
            draw(piece, in: box, canvas: canvas, labels: labels)
        }

        // Measures: the frame and the gaps of each piece, with the value in points.
        for dimension in layout.dimensions {
            draw(dimension, canvas: canvas)
        }

        // Colour legend at the foot of the page.
        if !page.legend.isEmpty {
            drawLegend(page, layout: layout, canvas: canvas, labels: labels)
        }

        canvas.text(String(format: labels.pageOf, pageIndex, pageCount), x: paper.width - m.margin,
                    baseline: paper.height - m.margin - 4, size: 8, colour: muted, align: .trailing)
    }

    private static func draw(_ piece: SheetPiece, in box: Rect, canvas: SheetCanvas, labels: SheetLabels) {
        let rule = SheetCanvas.grey(Grey.rule)
        switch piece.kind {
        case .swatch, .shape:
            if let hex = piece.fill, let colour = SheetCanvas.colour(hex: hex) {
                canvas.fill(box, colour)
            }
        case .image:
            if let data = piece.imageData, let image = PictureDecode.image(data) {
                drawFit(image, in: box, canvas: canvas)
            } else {
                canvas.fill(box, SheetCanvas.grey(Grey.placeholder))
                canvas.text(labels.image, x: box.x + box.w / 2, baseline: box.y + box.h / 2 + 3, size: 8,
                            colour: SheetCanvas.grey(Grey.muted), align: .centre, maxWidth: box.w)
            }
        case .code:
            canvas.fill(box, SheetCanvas.grey(Grey.piece))
        case .note, .text, .link, .group, .frame:
            break
        }
        canvas.stroke(box, rule, width: 0.5)

        let kind = String(localized: String.LocalizationValue(piece.kind.nameKey))
        var caption = [kind, piece.title].filter { !$0.isEmpty }.joined(separator: " · ")
        if let language = piece.language { caption += " · \(language.rawValue)" }
        if box.h >= 14 {
            canvas.text(caption, x: box.x + 3, baseline: box.y + 9, size: 7, colour: SheetCanvas.grey(Grey.ink),
                        maxWidth: box.w - 6)
        }
        if let text = piece.text, box.h >= 30 {
            canvas.text(text, x: box.x + 3, baseline: box.y + 22, size: 8, colour: SheetCanvas.grey(Grey.ink),
                        maxWidth: box.w - 6)
        }
    }

    /// Draws an image as large as possible inside the box, keeping its proportions.
    private static func drawFit(_ image: CGImage, in box: Rect, canvas: SheetCanvas) {
        let iw = Double(image.width)
        let ih = Double(image.height)
        guard iw > 0, ih > 0 else { return }
        let scale = min(box.w / iw, box.h / ih)
        let fitted = Rect(x: box.x + (box.w - iw * scale) / 2, y: box.y + (box.h - ih * scale) / 2,
                          w: iw * scale, h: ih * scale)
        canvas.context.draw(image, in: canvas.cgRect(fitted))
    }

    private static func draw(_ dimension: SheetDimension, canvas: SheetCanvas) {
        let colour = SheetCanvas.grey(Grey.muted)
        let tick = 3.0
        let label = "\(number(dimension.value)) pt"
        let size = 7.0
        switch dimension.axis {
        case .horizontal:
            canvas.line((dimension.from, dimension.line), (dimension.to, dimension.line), colour, width: 0.4)
            canvas.line((dimension.from, dimension.line - tick), (dimension.from, dimension.line + tick), colour, width: 0.4)
            canvas.line((dimension.to, dimension.line - tick), (dimension.to, dimension.line + tick), colour, width: 0.4)
            let mid = (dimension.from + dimension.to) / 2
            let textWidth = canvas.width(of: label, size: size)
            canvas.fill(Rect(x: mid - textWidth / 2 - 2, y: dimension.line - 5, w: textWidth + 4, h: 9),
                        SheetCanvas.grey(Grey.paper))
            canvas.text(label, x: mid, baseline: dimension.line + 2.5, size: size, colour: SheetCanvas.grey(Grey.ink), align: .centre)
        case .vertical:
            canvas.line((dimension.line, dimension.from), (dimension.line, dimension.to), colour, width: 0.4)
            canvas.line((dimension.line - tick, dimension.from), (dimension.line + tick, dimension.from), colour, width: 0.4)
            canvas.line((dimension.line - tick, dimension.to), (dimension.line + tick, dimension.to), colour, width: 0.4)
            let mid = (dimension.from + dimension.to) / 2
            let textWidth = canvas.width(of: label, size: size)
            canvas.fill(Rect(x: dimension.line - textWidth / 2 - 2, y: mid - 5, w: textWidth + 4, h: 9),
                        SheetCanvas.grey(Grey.paper))
            canvas.text(label, x: dimension.line, baseline: mid + 2.5, size: size, colour: SheetCanvas.grey(Grey.ink), align: .centre)
        }
    }

    private static func drawLegend(_ page: SheetPage, layout: SheetLayout, canvas: SheetCanvas, labels: SheetLabels) {
        let m = SheetLayout.Metrics.self
        let area = layout.legend
        let ink = SheetCanvas.grey(Grey.ink)
        canvas.text(labels.legend, x: area.x, baseline: area.y + m.legendGap + 12, size: 9, bold: true, colour: ink)
        if page.legendOverflow > 0 {
            canvas.text(String(format: labels.moreColours, page.legendOverflow), x: area.maxX, baseline: area.y + m.legendGap + 12,
                        size: 8, colour: SheetCanvas.grey(Grey.muted), align: .trailing)
        }
        let column = area.w / Double(m.legendColumns)
        let chip = 10.0
        for (index, swatch) in page.legend.enumerated() {
            let x = area.x + Double(index % m.legendColumns) * column
            let top = area.y + m.legendGap + m.legendHeader + Double(index / m.legendColumns) * m.legendRow
            let box = Rect(x: x, y: top + 2, w: chip, h: chip)
            canvas.fill(box, SheetCanvas.colour(hex: swatch.hex) ?? SheetCanvas.grey(Grey.placeholder))
            canvas.stroke(box, SheetCanvas.grey(Grey.rule), width: 0.5)
            let text = swatch.name.map { "\(swatch.hex)  \($0)" } ?? swatch.hex
            canvas.text(text, x: x + chip + 6, baseline: top + 10, size: 8, colour: ink, maxWidth: column - chip - 10)
        }
    }

    /// A number with at most one decimal, in the language of the Mac.
    private static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}
