import AppKit
import Core
import Design
import Hub
import Mail
import Shell
import SwiftUI
import UniformTypeIdentifiers

struct DraftEditor: View {
    @Environment(\.appearance) private var appearance
    let session: AppSession
    let card: OpenDraft
    @State private var showCopy = false
    @State private var expanded = false
    @State private var box = TextBox()
    @State private var dropOver = false
    @State private var reveal = 0
    private static let attachmentStrip = "draft.attachments"

    private var inbox: InboxState { session.inbox }
    private var account: Inlet? { inbox.accounts.first { $0.id == card.inlet } }
    private var hasCopy: Bool { !card.people(.cc).isEmpty || !card.people(.bcc).isEmpty }
    private var copyShown: Binding<Bool> { Binding(get: { showCopy || hasCopy }, set: { showCopy = $0 }) }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    fields
                }
                .scrollIndicators(.automatic)
                .onChange(of: reveal) { proxy.scrollTo(Self.attachmentStrip, anchor: .bottom) }
            }
            if inbox.formatting { FormatRow(box: box) }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $dropOver) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    Task { @MainActor in session.attach(urls: [url], to: card.id) }
                }
            }
            return true
        }
        .overlay { if dropOver { dropOverlay } }
        .onChange(of: hasCopy, initial: true) { _, filled in
            if filled { showCopy = true }
        }
    }

    private var dropOverlay: some View {
        let shape = RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.notice))
        return HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
            Glyph(.doc)
            appearance.text("mail.compose.drop")
        }
        .designText(\.ink, size: Tokens.TextSize.body, weight: .medium)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(shape.fill(appearance.color(\.well)))
        .overlay(shape.strokeBorder(appearance.color(\.inkTertiary),
                                    style: StrokeStyle(lineWidth: CGFloat(Tokens.Size.hairline),
                                                       dash: SheetValues.dashedLine.map { CGFloat($0) })))
        .padding(CGFloat(Tokens.Spacing.step8))
        .allowsHitTesting(false)
    }

    private var fields: some View {
        VStack(spacing: 0) {
            if card.needsGrant {
                Notice(kind: .warning, title: appearance.text("mail.draft.grant.title"), text: appearance.text("mail.draft.grant.text"),
                       glyph: { Glyph(.alert) },
                       actions: { TextButton(label: appearance.text("mail.draft.grant.act"), kind: .accent) { session.openMailCard(of: account) } })
                    .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
                    .padding(.top, CGFloat(Tokens.Spacing.step8))
            } else if card.tooLarge {
                Notice(kind: .failure, title: appearance.text("mail.notice.tooLarge.title"), text: appearance.text("mail.notice.tooLarge.text"),
                       glyph: { Glyph(.alert) },
                       actions: { TextButton(label: appearance.text("mail.notice.tooLarge.act"), kind: .accent) { reveal += 1 } })
                    .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
                    .padding(.top, CGFloat(Tokens.Spacing.step8))
            } else if card.failedToSend {
                Notice(kind: .failure, title: appearance.text("mail.draft.sendFailed"), text: appearance.text("mail.draft.failed.text"),
                       glyph: { Glyph(.alert) },
                       actions: { TextButton(label: appearance.text("mail.draft.failed.act"), kind: .accent) { Task { await inbox.send(card.id) } } })
                    .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
                    .padding(.top, CGFloat(Tokens.Spacing.step8))
            }
            if inbox.planning == card.id {
                PlanNotice(inbox: inbox, card: card.id)
                    .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
                    .padding(.top, CGFloat(Tokens.Spacing.step8))
            }
            if card.saveFailure != nil, !card.needsGrant, !card.failedToSend {
                Notice(kind: .failure, title: appearance.text("mail.draft.saveFailed.title"),
                       text: appearance.text(card.saveNeedsSignIn ? "mail.draft.saveFailed.auth" : "mail.draft.saveFailed.server"),
                       glyph: { Glyph(.alert) },
                       actions: {
                    if card.saveNeedsSignIn {
                        TextButton(label: appearance.text("mail.list.signInExpired.act"), kind: .accent) { session.openMailCard(of: account) }
                    } else {
                        TextButton(label: appearance.text("mail.draft.saveFailed.retry"), kind: .accent) { Task { await inbox.save(card.id) } }
                    }
                })
                    .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
                    .padding(.top, CGFloat(Tokens.Spacing.step8))
            }
            FieldRow(label: appearance.text("mail.compose.from"), width: Tokens.Size.fieldLabelWidth, gap: 0) {
                FromButton(session: session, card: card)
                Spacer(minLength: 0)
            }
            RecipientEditor(inbox: inbox, card: card, field: .to, showCopy: copyShown, expanded: $expanded)
            if copyShown.wrappedValue {
                RecipientEditor(inbox: inbox, card: card, field: .cc, showCopy: copyShown, expanded: $expanded)
                RecipientEditor(inbox: inbox, card: card, field: .bcc, showCopy: copyShown, expanded: $expanded)
            }
            subjectRow
            bodySheet
            if !card.draft.attachments.isEmpty { attachments.id(Self.attachmentStrip) }
        }
    }

    private var subjectRow: some View {
        let binding = Binding(get: { card.draft.subject }, set: { value in inbox.edit(card.id) { $0.subject = value } })
        return FieldRow(label: appearance.text("mail.compose.subject"), width: Tokens.Size.recipientLabelColumn) {
            TextField(text: binding, prompt: appearance.text("mail.compose.subject")) { appearance.text("mail.compose.subject") }
                .textFieldStyle(.plain)
                .designText(\.ink, size: Tokens.TextSize.body, weight: .medium)
                .padding(.leading, CGFloat(Tokens.Spacing.step4))
                .autocorrectionDisabled()
        }
    }

    private var bodySheet: some View {
        BodyEditor(text: card.draft.body, html: card.draft.bodyHTML, signature: card.draft.signed, box: box) { text, html in
            inbox.setBody(card.id, text: text, html: html)
        }
            .frame(minHeight: CGFloat(Tokens.Size.composeTextMinHeight))
            .padding(.top, CGFloat(Tokens.Spacing.step16))
            .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
            .padding(.bottom, CGFloat(Tokens.Spacing.step8))
            .frame(maxWidth: .infinity, minHeight: CGFloat(Tokens.Size.composeSheetMinHeight), alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.row)).fill(appearance.color(\.sheet)))
            .environment(\.colorScheme, .light)
            .padding(CGFloat(Tokens.Spacing.step8))
    }

    private var attachments: some View {
        ScrollView(.horizontal) {
            HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
                ForEach(Array(card.draft.attachments.enumerated()), id: \.offset) { index, item in
                    AttachmentChip(name: PersonName.middle(item.filename, limit: SheetValues.attachmentNameLimit), size: item.humanSize,
                                   detail: item.filename, removeKey: "mail.compose.remove",
                                   onRemove: { inbox.removeAttachment(card.id, at: index) }, glyph: { Glyph.small(.doc) },
                                   removeGlyph: { Glyph.tiny(.close) })
                }
            }
            .padding(.horizontal, CGFloat(Tokens.Size.edge))
            .padding(.bottom, CGFloat(Tokens.Spacing.step8))
        }
        .scrollIndicators(.hidden)
    }
}

struct FieldRow<Content: View>: View {
    let label: Text
    let width: Double
    var gap = Tokens.Spacing.step8
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: CGFloat(gap)) {
            label.designText(\.inkTertiary, size: Tokens.TextSize.small).frame(width: CGFloat(width), alignment: .leading)
            content
        }
        .padding(.leading, CGFloat(Tokens.Size.edge))
        .padding(.trailing, CGFloat(Tokens.Spacing.step8))
        .frame(height: CGFloat(Tokens.Spacing.step44))
        .overlay(alignment: .bottom) {
            Hairline().padding(.horizontal, CGFloat(Tokens.Size.edge))
        }
    }
}

struct FromButton: View {
    @Environment(\.appearance) private var appearance
    let session: AppSession
    let card: OpenDraft
    @State private var anchor = AnchorBox()

    private var inbox: InboxState { session.inbox }
    private var sender: Inlet? { inbox.accounts.first { $0.id == card.inlet } }
    private var name: String { card.draft.from?.name ?? "" }
    private var address: String { card.draft.from?.address ?? sender?.account ?? "" }

    var body: some View {
        AddressButton(capsule: true, action: open) {
            HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
                if name.isEmpty {
                    Text(verbatim: address).designText(\.ink, size: Tokens.TextSize.body, weight: .medium).lineLimit(1)
                } else {
                    Text(verbatim: name).designText(\.ink, size: Tokens.TextSize.body, weight: .medium).lineLimit(1).layoutPriority(1)
                    Text(verbatim: address).designText(\.inkTertiary, size: Tokens.TextSize.small).lineLimit(1).truncationMode(.tail)
                }
                Glyph.small(.chevron).foregroundStyle(appearance.color(\.inkTertiary))
            }
        }
        .background(AnchorMarker(box: anchor))
    }

    private func open() {
        var entries = inbox.senderChoices.map { choice in
            MenuEntry.row(MenuItem(id: choice.id, label: Text(verbatim: choice.sender.address),
                                   check: isCurrent(choice) ? appearance.text("mail.menu.check") : nil) {
                Task { await inbox.setFrom(card.id, inlet: choice.inlet, sender: choice.sender) }
            })
        }
        entries.append(contentsOf: signatureEntries())
        anchor.showMenu(entries)
        Task { await inbox.refreshSenders() }
    }

    private func signatureEntries() -> [MenuEntry] {
        let applied = inbox.signatureApplied(card.id)
        var entries: [MenuEntry] = [
            .separator(id: "signature.separator"),
            .row(MenuItem(id: "signature.none", label: appearance.text("mail.compose.signature.none"),
                          check: applied ? nil : appearance.text("mail.menu.check")) { inbox.useSignature(card.id, false) }),
        ]
        if let name = inbox.signatureName(card.id) {
            entries.append(.row(MenuItem(id: "signature.use", label: Text(verbatim: name),
                                         check: applied ? appearance.text("mail.menu.check") : nil) { inbox.useSignature(card.id, true) }))
        }
        entries.append(.row(MenuItem(id: "signature.edit", label: appearance.text("mail.compose.signature.edit")) {
            session.openMailCard(of: sender)
        }))
        return entries
    }

    private func isCurrent(_ choice: SenderChoice) -> Bool {
        choice.inlet == card.inlet && choice.sender.address.lowercased() == address.lowercased()
    }
}

private struct PlanNotice: View {
    @Environment(\.appearance) private var appearance
    let inbox: InboxState
    let card: UUID
    @State private var date = Date()

    var body: some View {
        Notice(kind: .warning, title: appearance.text("mail.later.folder"), text: nil, glyph: { Glyph(.clock) }, actions: {
            VStack(alignment: .leading, spacing: CGFloat(Tokens.Spacing.step8)) {
                DatePicker(selection: $date, in: inbox.now..., displayedComponents: [.date, .hourAndMinute]) {
                    appearance.text("mail.later.dateTime")
                }
                .labelsHidden()
                .datePickerStyle(.field)
                .environment(\.locale, appearance.locale)
                .help(appearance.text("mail.later.dateTime"))
                HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
                    TextButton(label: appearance.text("mail.later.plan"), kind: .accent, disabled: date <= inbox.now) {
                        Task { await inbox.plan(card, at: date) }
                    }
                    TextButton(label: appearance.text("text.common.cancel"), kind: .plain) { inbox.cancelPlan() }
                }
            }
        })
        .onAppear { date = inbox.planChoices.first ?? inbox.now }
    }
}

struct ComposeHead: View {
    @Environment(\.appearance) private var appearance
    let account: Inlet?
    let display: MailboxDisplay
    let named: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let side = CGFloat(Tokens.Size.symbolSize)
        let ink = appearance.color(\.ink)
        HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
            Button(action: action) {
                DeckRow(trailing: 0) {
                    Glyph(.compose)
                        .frame(width: side, height: side)
                        .background(Circle().fill(hovering ? appearance.color(\.hover) : Color.clear))
                        .ring(Circle(), hovering ? appearance.color(\.inkTertiary) : ink.opacity(Tokens.Opacity.ringOnMark))
                } label: {
                    appearance.text("mail.action.compose")
                        .typeStyle(Tokens.TextStyle.bodyEmphasis)
                        .lineLimit(1)
                }
                .foregroundStyle(ink)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressScaleButtonStyle(scale: Tokens.Scale.pressTile))
            .keyboardShortcut("n", modifiers: .command)
            .disabled(account == nil)
            .help(appearance.text("mail.action.compose"))
            .onHover { hovering = $0 }
            .layoutPriority(1)
            if let account {
                Text(verbatim: account.shownName(display, appearance: appearance))
                    .typeStyle(Tokens.TextStyle.caption)
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .opacity(named ? Tokens.Opacity.cardMeta : 0)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, Deck.toggleRoom)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Deck.row)
        .animation(appearance.ease(Tokens.Duration.hover), value: hovering)
    }
}

struct FormatRow: View {
    @Environment(\.appearance) private var appearance
    let box: TextBox

    var body: some View {
        HStack(spacing: CGFloat(Tokens.Spacing.step4)) {
            item("mail.format.bold", .bold) { box.toggle(.boldFontMask) }
            item("mail.format.italic", .italic) { box.toggle(.italicFontMask) }
            item("mail.format.underline", .underline) { box.toggleUnderline() }
            item("mail.format.list", .list) { box.toggleList(.bullet) }
            item("mail.format.numbered", .numbered) { box.toggleList(.number) }
            item("mail.format.link", .link) { askLink() }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
        .frame(height: CGFloat(Tokens.Spacing.step44))
        .overlay(alignment: .top) { Hairline() }
    }

    private func item(_ key: String, _ glyph: Icon, _ action: @escaping () -> Void) -> some View {
        SymbolButton(help: appearance.string(key), glyph: glyph, side: Tokens.Spacing.step28, tone: \.inkSecondary, hover: .fill, action: action)
    }

    private func askLink() {
        let alert = NSAlert()
        alert.messageText = appearance.string("mail.format.link")
        let field = NSTextField(string: "")
        field.placeholderString = appearance.string("mail.format.linkPlaceholder")
        field.frame.size.width = CGFloat(SheetValues.linkFieldWidth)
        alert.accessoryView = field
        alert.addButton(withTitle: appearance.string("mail.format.linkApply"))
        alert.addButton(withTitle: appearance.string("mail.format.linkCancel"))
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        box.link(field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

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
