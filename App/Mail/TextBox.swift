import AppKit
import Mail

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
