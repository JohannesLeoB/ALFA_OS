import AppKit
import Design
import Mail
import SwiftUI

struct BodyEditor: NSViewRepresentable {
    @Environment(\.appearance) private var appearance
    let text: String
    let html: String?
    let box: TextBox
    let change: (String, String?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(box: box, change: change)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.drawsBackground = false
        guard let view = scroll.documentView as? NSTextView else { return scroll }
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
    }

    private var base: [NSAttributedString.Key: Any] {
        let style = Tokens.TextStyle.mailBody
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = Typeface.spacing(size: style.size, line: style.lineHeight)
        let ink = appearance.colors.sheetInk
        return [.font: Typeface.font(size: style.size, weight: Tokens.Weight.regular), .paragraphStyle: paragraph,
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
        let font = Typeface.font(size: Tokens.TextStyle.mailBody.size, weight: Tokens.Weight.regular)
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
            change(view.string, RichTextEngine.html(TextBox.paragraphs(storage)))
        }

        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            selector == #selector(NSResponder.insertNewline(_:)) ? box.continueList() : false
        }
    }
}
