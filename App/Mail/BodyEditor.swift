import AppKit
import Design
import Mail
import SwiftUI

struct BodyEditor: NSViewRepresentable {
    @Environment(\.appearance) private var appearance
    let text: String
    let html: String?
    var signature: String?
    let box: TextBox
    let change: (String, String?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(box: box, change: change)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        let view = SignatureTextView(frame: .zero)
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.autoresizingMask = [.width]
        view.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        view.textContainer?.widthTracksTextView = true
        scroll.documentView = view
        view.isRichText = true
        view.allowsUndo = true
        view.isContinuousSpellCheckingEnabled = true
        view.isAutomaticSpellingCorrectionEnabled = false
        view.drawsBackground = false
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        view.typingAttributes = base
        view.textStorage?.setAttributedString(content(html: html))
        view.delegate = context.coordinator
        view.mark(signature, colors: appearance.colors)
        view.setAccessibilityLabel(appearance.string("mail.compose.body"))
        box.view = view
        DispatchQueue.main.async {
            DispatchQueue.main.async {
                guard let window = view.window, !(window.firstResponder is NSText) else { return }
                window.makeFirstResponder(view)
                view.setSelectedRange(NSRange(location: 0, length: 0))
            }
        }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.change = change
        guard let view = scroll.documentView as? NSTextView else { return }
        box.view = view
        if view.string != text { view.textStorage?.setAttributedString(content(html: html)) }
        (view as? SignatureTextView)?.mark(signature, colors: appearance.colors)
    }

    private var base: [NSAttributedString.Key: Any] {
        let style = Tokens.TextStyle.mailBody
        let paragraph = NSMutableParagraphStyle()
        let face = Typeface.draft(size: style.size)
        paragraph.lineSpacing = Typeface.spacing(size: style.size, line: style.lineHeight, face: face)
        let ink = appearance.colors.sheetInk
        return [.font: face, .paragraphStyle: paragraph,
                .foregroundColor: NSColor(srgbRed: ink.red, green: ink.green, blue: ink.blue, alpha: ink.alpha)]
    }

    private func content(html: String?) -> NSAttributedString {
        guard let html, let data = html.data(using: .utf8),
              let parsed = try? NSMutableAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html,
                                                                                .characterEncoding: String.Encoding.utf8.rawValue],
                                                          documentAttributes: nil) else {
            return NSAttributedString(string: text, attributes: base)
        }
        let whole = NSRange(location: 0, length: parsed.length)
        let font = Typeface.draft(size: Tokens.TextStyle.mailBody.size)
        let manager = NSFontManager.shared
        parsed.enumerateAttribute(.font, in: whole) { value, part, _ in
            let traits = (value as? NSFont).map { manager.traits(of: $0) } ?? []
            parsed.addAttribute(.font, value: manager.convert(font, toHaveTrait: traits.intersection([.boldFontMask, .italicFontMask])), range: part)
        }
        for key in [NSAttributedString.Key.foregroundColor, .paragraphStyle] { parsed.addAttribute(key, value: base[key] as Any, range: whole) }
        return parsed
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        let box: TextBox
        var change: (String, String?) -> Void

        init(box: TextBox, change: @escaping (String, String?) -> Void) {
            self.box = box
            self.change = change
        }

        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView, let storage = view.textStorage else { return }
            (view as? SignatureTextView)?.refresh()
            change(view.string, RichTextEngine.html(TextBox.paragraphs(storage)))
        }

        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            selector == #selector(NSResponder.insertNewline(_:)) ? box.continueList() : false
        }
    }
}

final class SignatureTextView: NSTextView {
    private var signature: String?
    private var colors = Colors.light

    func mark(_ text: String?, colors: Colors) {
        self.colors = colors
        guard text != signature else { return }
        signature = text
        refresh()
    }

    func refresh() {
        guard let manager = layoutManager else { return }
        let whole = NSRange(location: 0, length: (string as NSString).length)
        manager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: whole)
        if let range = signatureRange {
            let lines = (string as NSString).substring(with: range) as NSString
            let first = lines.range(of: "\n")
            let rest = first.location == NSNotFound ? NSRange(location: NSNotFound, length: 0)
                : NSRange(location: range.location + first.location, length: range.length - first.location)
            if rest.location != NSNotFound { manager.addTemporaryAttribute(.foregroundColor, value: color(colors.sheetInkTertiary), forCharacterRange: rest) }
        }
        needsDisplay = true
    }

    private var signatureRange: NSRange? {
        guard let signature, !signature.isEmpty else { return nil }
        let range = (string as NSString).range(of: signature, options: .backwards)
        return range.location == NSNotFound ? nil : range
    }

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        guard let range = signatureRange, let manager = layoutManager else { return }
        let glyph = manager.glyphIndexForCharacter(at: range.location)
        let line = manager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        let rule = NSRect(x: line.minX + textContainerOrigin.x, y: line.minY + textContainerOrigin.y - CGFloat(Tokens.Spacing.step8),
                          width: CGFloat(Tokens.Spacing.step24), height: CGFloat(Tokens.Size.hairline))
        color(colors.sheetLineStrong).setFill()
        rule.fill()
    }

    private func color(_ value: ColorValue) -> NSColor {
        NSColor(srgbRed: value.red, green: value.green, blue: value.blue, alpha: value.alpha)
    }
}
