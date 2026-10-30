import CoreGraphics
import CoreText
import Design
import Foundation

public enum MessagePDF {
    public static func render(_ message: OpenMessage, page: CGSize, margin: CGFloat) -> Data? {
        let body: String
        switch message.content {
        case .text(let text): body = text
        case .html(let html, _): body = HTMLEngine.plain(html)
        default: body = message.summary.snippet
        }
        let date = message.summary.receivedAt.map { $0.formatted(date: .long, time: .shortened) }
        let head = [message.summary.subject, message.summary.from, date].compactMap { $0 }.filter { !$0.isEmpty }
        return render(text: (head + ["", body]).joined(separator: "\n"), page: page, margin: margin)
    }

    public static func render(text: String, page: CGSize, margin: CGFloat) -> Data? {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { return nil }
        var box = CGRect(origin: .zero, size: page)
        guard let context = CGContext(consumer: consumer, mediaBox: &box, nil) else { return nil }
        let font = CTFontCreateUIFontForLanguage(.system, Tokens.TextSize.body, nil)
        let key = NSAttributedString.Key(rawValue: kCTFontAttributeName as String)
        let string = NSAttributedString(string: text, attributes: font.map { [key: $0] })
        let setter = CTFramesetterCreateWithAttributedString(string)
        let path = CGPath(rect: box.insetBy(dx: margin, dy: margin), transform: nil)
        var start = 0
        repeat {
            context.beginPDFPage(nil)
            let frame = CTFramesetterCreateFrame(setter, CFRange(location: start, length: 0), path, nil)
            CTFrameDraw(frame, context)
            context.endPDFPage()
            let shown = CTFrameGetVisibleStringRange(frame).length
            if shown == 0 { break }
            start += shown
        } while start < string.length
        context.closePDF()
        return data as Data
    }
}
