import AppKit
import Core
import Design
import Hub
import Mail
import Shell
import SwiftUI
import UniformTypeIdentifiers

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
        view.typingAttributes = defaultAttributes
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

    private var defaultAttributes: [NSAttributedString.Key: Any] {
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
            return NSAttributedString(string: text, attributes: defaultAttributes)
        }
        let whole = NSRange(location: 0, length: parsed.length)
        let font = Typeface.draft(size: Tokens.TextStyle.mailBody.size)
        let manager = NSFontManager.shared
        parsed.enumerateAttribute(.font, in: whole) { value, part, _ in
            let traits = (value as? NSFont).map { manager.traits(of: $0) } ?? []
            parsed.addAttribute(.font, value: manager.convert(font, toHaveTrait: traits.intersection([.boldFontMask, .italicFontMask])), range: part)
        }
        for key in [NSAttributedString.Key.foregroundColor, .paragraphStyle] { parsed.addAttribute(key, value: defaultAttributes[key] as Any, range: whole) }
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

@MainActor
final class TextBox {
    static let listKey = NSAttributedString.Key("list.kind")
    weak var view: NSTextView?

    func toggle(_ trait: NSFontTraitMask) {
        guard let view, let storage = view.textStorage else { return }
        let manager = NSFontManager.shared
        let range = view.selectedRange()
        let flip = { (font: NSFont, on: Bool) in on ? manager.convert(font, toNotHaveTrait: trait) : manager.convert(font, toHaveTrait: trait) }
        guard range.length > 0 else {
            if let font = view.typingAttributes[.font] as? NSFont {
                view.typingAttributes[.font] = flip(font, manager.traits(of: font).contains(trait))
            }
            return
        }
        var all = true
        storage.enumerateAttribute(.font, in: range) { value, _, stop in
            if let font = value as? NSFont, !manager.traits(of: font).contains(trait) {
                all = false
                stop.pointee = true
            }
        }
        change(range) {
            storage.enumerateAttribute(.font, in: range) { value, part, _ in
                if let font = value as? NSFont { storage.addAttribute(.font, value: flip(font, all), range: part) }
            }
        }
    }

    func toggleUnderline() {
        guard let view, let storage = view.textStorage else { return }
        let range = view.selectedRange()
        let single = NSUnderlineStyle.single.rawValue
        guard range.length > 0 else {
            let on = (view.typingAttributes[.underlineStyle] as? Int ?? 0) != 0
            view.typingAttributes[.underlineStyle] = on ? nil : single
            return
        }
        var all = true
        storage.enumerateAttribute(.underlineStyle, in: range) { value, _, stop in
            if (value as? Int ?? 0) == 0 {
                all = false
                stop.pointee = true
            }
        }
        change(range) {
            if all { storage.removeAttribute(.underlineStyle, range: range) } else { storage.addAttribute(.underlineStyle, value: single, range: range) }
        }
    }

    func link(_ address: String) {
        guard let view, let storage = view.textStorage, !address.isEmpty else { return }
        let range = view.selectedRange()
        if range.length > 0 {
            change(range) { storage.addAttribute(.link, value: address, range: range) }
        } else {
            var attributes = view.typingAttributes
            attributes[.link] = address
            change(range) { storage.insert(NSAttributedString(string: address, attributes: attributes), at: range.location) }
        }
    }

    func toggleList(_ kind: ListKind) {
        guard let view, let storage = view.textStorage else { return }
        let text = storage.string as NSString
        let whole = text.paragraphRange(for: view.selectedRange())
        var paragraphs: [NSRange] = []
        text.enumerateSubstrings(in: whole, options: [.byParagraphs, .substringNotRequired]) { _, range, _, _ in paragraphs.append(range) }
        if paragraphs.isEmpty { paragraphs = [NSRange(location: whole.location, length: 0)] }
        let on = paragraphs.allSatisfy { Self.kind(storage, at: $0.location) == kind }
        change(whole) {
            var shift = 0
            var position = 0
            for range in paragraphs {
                let start = range.location + shift
                let old = Self.markerLength(storage, at: start)
                storage.deleteCharacters(in: NSRange(location: start, length: old))
                shift -= old
                let length = range.length - old
                storage.removeAttribute(Self.listKey, range: NSRange(location: start, length: length))
                guard !on else { continue }
                position += 1
                let marker = RichTextEngine.marker(kind, position: position)
                var attributes = view.typingAttributes
                if start < storage.length { attributes = storage.attributes(at: start, effectiveRange: nil) }
                attributes[.link] = nil
                storage.insert(NSAttributedString(string: marker, attributes: attributes), at: start)
                let size = (marker as NSString).length
                shift += size
                storage.addAttribute(Self.listKey, value: kind.rawValue, range: NSRange(location: start, length: length + size))
            }
        }
    }

    func continueList() -> Bool {
        guard let view, let storage = view.textStorage else { return false }
        let caret = view.selectedRange()
        let text = storage.string as NSString
        let paragraph = text.paragraphRange(for: NSRange(location: caret.location, length: 0))
        guard let kind = Self.kind(storage, at: paragraph.location) else { return false }
        let marker = Self.markerLength(storage, at: paragraph.location)
        let content = text.substring(with: paragraph).trimmingCharacters(in: .newlines)
        if (content as NSString).length <= marker {
            change(paragraph) {
                storage.deleteCharacters(in: NSRange(location: paragraph.location, length: marker))
                storage.removeAttribute(Self.listKey, range: NSRange(location: paragraph.location, length: paragraph.length - marker))
            }
            return true
        }
        let current = Int(text.substring(with: NSRange(location: paragraph.location, length: marker)).filter(\.isNumber)) ?? 0
        let next = "\n" + RichTextEngine.marker(kind, position: current + 1)
        view.insertText(next, replacementRange: caret)
        storage.addAttribute(Self.listKey, value: kind.rawValue, range: NSRange(location: caret.location + 1, length: (next as NSString).length - 1))
        return true
    }

    private func change(_ range: NSRange, _ work: () -> Void) {
        guard let view, let storage = view.textStorage, view.shouldChangeText(in: range, replacementString: nil) else { return }
        storage.beginEditing()
        work()
        storage.endEditing()
        view.didChangeText()
    }

    static func kind(_ storage: NSTextStorage, at location: Int) -> ListKind? {
        guard location < storage.length else { return nil }
        return (storage.attribute(listKey, at: location, effectiveRange: nil) as? String).flatMap(ListKind.init(rawValue:))
    }

    static func markerLength(_ storage: NSTextStorage, at location: Int) -> Int {
        guard let kind = kind(storage, at: location) else { return 0 }
        let rest = (storage.string as NSString).substring(from: location)
        switch kind {
        case .bullet:
            let marker = RichTextEngine.marker(.bullet, position: 1)
            return rest.hasPrefix(marker) ? (marker as NSString).length : 0
        case .number:
            let digits = rest.prefix { $0.isNumber }
            let tail = rest.dropFirst(digits.count)
            return !digits.isEmpty && tail.hasPrefix(". ") ? digits.count + 2 : 0
        }
    }

    static func paragraphs(_ storage: NSTextStorage) -> [RichParagraph] {
        let text = storage.string as NSString
        let manager = NSFontManager.shared
        var result: [RichParagraph] = []
        text.enumerateSubstrings(in: NSRange(location: 0, length: text.length), options: [.byParagraphs, .substringNotRequired]) { _, range, _, _ in
            let kind = kind(storage, at: range.location)
            let skip = kind == nil ? 0 : markerLength(storage, at: range.location)
            var runs: [RichRun] = []
            storage.enumerateAttributes(in: NSRange(location: range.location + skip, length: range.length - skip)) { attributes, part, _ in
                let traits = (attributes[.font] as? NSFont).map { manager.traits(of: $0) } ?? []
                let link = (attributes[.link] as? URL)?.absoluteString ?? attributes[.link] as? String
                runs.append(RichRun(text.substring(with: part), bold: traits.contains(.boldFontMask), italic: traits.contains(.italicFontMask),
                                    underline: (attributes[.underlineStyle] as? Int ?? 0) != 0, link: link))
            }
            result.append(RichParagraph(list: kind, runs: runs))
        }
        return result
    }
}
