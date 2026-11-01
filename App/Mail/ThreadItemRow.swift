import AppKit
import Core
import Design
import Mail
import PDFKit
import QuickLookUI
import SwiftUI
import UniformTypeIdentifiers
import WebKit

struct ThreadItemRow: View {
    @Environment(\.appearance) private var appearance
    let session: AppSession
    let card: OpenMessage
    let item: ThreadItem
    let first: Bool
    let last: Bool
    @State private var anchor = AnchorBox()
    @State private var recipientsOpen = false

    private var loadImages: Bool { session.settings.loadImages(card.inlet) }

    private var allowRemote: Bool { !card.remoteImagesBlocked(loadRemote: loadImages) }

    private func sheet(_ size: Double, _ weight: Font.Weight = .regular) -> Font {
        Font(Typeface.font(size: size, weight: weight))
    }

    var body: some View {
        let style = Tokens.TextStyle.mailBody
        VStack(alignment: .leading, spacing: CGFloat(Tokens.Spacing.step8)) {
            HStack(alignment: .firstTextBaseline, spacing: CGFloat(Tokens.Spacing.step8)) {
                AddressButton(action: menu) {
                    Text(verbatim: item.name)
                        .font(sheet(style.size, .medium))
                        .lineHeight(style.lineHeight, size: style.size)
                }
                .background(AnchorMarker(box: anchor))
                Spacer(minLength: 0)
                if let date = item.date { threadDate(date) }
            }
            if !item.current, !item.recipients.all.isEmpty { recipientLines }
            if let html = allowRemote ? item.html : item.blockedHTML, case .html(_, let inline) = card.content {
                HTMLBody(inbox: session.inbox, card: card, html: html, inlineImages: inline,
                         allowRemote: allowRemote)
            } else {
                Text(linked(item.text))
                    .font(sheet(style.size))
                    .lineHeight(style.lineHeight, size: style.size)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let signature = item.signature {
                QuoteToggle(label: item.signatureOpen ? appearance.text("mail.signature.hide") : appearance.text("mail.signature.show")) {
                    session.inbox.toggleSignature(card.id, message: item.id)
                }
                if item.signatureOpen {
                    Text(linked(signature.text))
                        .font(sheet(Tokens.TextSize.body))
                        .foregroundStyle(appearance.color(\.sheetInkTertiary))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if let quote = item.quote {
                QuoteToggle(label: item.quoteOpen ? appearance.text("mail.quote.hide") : Text(verbatim: appearance.format("mail.quote.show", String(quote.lines)))) {
                    session.inbox.toggleQuote(card.id, message: item.id)
                }
                if item.quoteOpen {
                    Text(linked(quote.text))
                        .font(sheet(Tokens.TextSize.body))
                        .foregroundStyle(appearance.color(\.sheetInkTertiary))
                        .padding(.leading, CGFloat(Tokens.Spacing.step12))
                        .overlay(alignment: .leading) {
                            Rectangle().fill(appearance.color(\.sheetLine)).frame(width: CGFloat(Tokens.Size.quoteBarWidth))
                        }
                }
            }
            if last, !card.attachmentEntries.isEmpty {
                VStack(spacing: 0) {
                    ForEach(card.attachmentEntries) { row in
                        AttachmentRow(session: session, card: card, row: row)
                    }
                }
                .padding(.horizontal, -CGFloat(Tokens.Spacing.step8))
                .padding(.top, CGFloat(Tokens.Spacing.step4))
            }
        }
        .padding(.top, CGFloat(first ? 0 : Tokens.Spacing.step16))
        .id(item.id)
        .overlay(alignment: .top) {
            if !first { Rectangle().fill(appearance.color(\.sheetLine)).frame(height: CGFloat(Tokens.Size.hairline)) }
        }
        .padding(.top, CGFloat(Tokens.Spacing.step16))
    }

    @ViewBuilder
    private var recipientLines: some View {
        let people = item.recipients
        VStack(alignment: .leading, spacing: 0) {
            Disclosure(open: recipientsOpen, help: appearance.string(recipientsOpen ? "mail.read.less" : "mail.read.all")) {
                HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
                    appearance.text("mail.read.to").font(sheet(Tokens.TextSize.small))
                        .foregroundStyle(appearance.color(\.sheetInkTertiary))
                    Text(verbatim: recipientsOpen ? appearance.format("mail.read.count", Format.number(people.all.count)) : people.summary)
                        .font(sheet(Tokens.TextSize.small, .medium))
                        .foregroundStyle(appearance.color(\.sheetInkSecondary))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if !recipientsOpen, let more = people.more {
                        Text(verbatim: appearance.format("mail.read.more", Format.number(more)))
                            .font(sheet(Tokens.TextSize.small))
                            .foregroundStyle(appearance.color(\.sheetInkTertiary))
                    }
                }
            } action: { recipientsOpen.toggle() }
            if recipientsOpen {
                recipientGroup("mail.read.to", people.to)
                recipientGroup("mail.read.cc", people.cc)
            }
        }
        .animation(appearance.ease(Tokens.Duration.recipientList), value: recipientsOpen)
    }

    @ViewBuilder
    private func recipientGroup(_ key: String, _ people: [Participant]) -> some View {
        if !people.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: CGFloat(Tokens.Spacing.step8)) {
                appearance.text(key)
                    .font(sheet(Tokens.TextSize.small))
                    .foregroundStyle(appearance.color(\.sheetInkTertiary))
                Text(verbatim: people.map(\.label).joined(separator: ", "))
                    .font(sheet(Tokens.TextSize.small))
                    .foregroundStyle(appearance.color(\.sheetInkSecondary))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func linked(_ text: String) -> AttributedString {
        var result = LinkEngine.attributed(text)
        let ranges = result.runs.filter { $0.link != nil }.map(\.range)
        for range in ranges {
            result[range][AttributeScopes.SwiftUIAttributes.UnderlineStyleAttribute.self] = .single
        }
        return result
    }

    @ViewBuilder
    private func threadDate(_ date: ThreadDate) -> some View {
        Group {
            switch date {
            case .today(let value):
                Text(verbatim: appearance.format("mail.date.todayAt", value.formatted(.dateTime.hour().minute().locale(appearance.locale))))
            case .dated(let value, let withYear):
                withYear ? Text(value, format: .dateTime.day().month(.abbreviated).year().hour().minute().locale(appearance.locale))
                    : Text(value, format: .dateTime.day().month(.abbreviated).hour().minute().locale(appearance.locale))
            }
        }
        .font(sheet(Tokens.TextSize.small))
        .foregroundStyle(appearance.color(\.sheetInkTertiary))
        .monospacedDigit()
        .lineLimit(1)
        .fixedSize()
    }

    private func menu() {
        let entries = session.personEntries(name: item.name, address: item.address, appearance: appearance)
        anchor.showMenu(entries)
    }
}

struct QuoteToggle: View {
    @Environment(\.appearance) private var appearance
    let label: Text
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            label
                .typeStyle(Tokens.TextStyle.control)
                .foregroundStyle(appearance.color(\.sheetInkSecondary))
                .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
                .frame(height: CGFloat(Tokens.Size.chipHeight))
                .ring(Pill(), appearance.color(\.lineStrong))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

final class MessageWebView: WKWebView {
    var onWidthChange: (() -> Void)?
    private var lastWidth: CGFloat = 0

    override func scrollWheel(with event: NSEvent) {
        nextResponder?.scrollWheel(with: event)
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        guard abs(newSize.width - lastWidth) > 1, newSize.width > 0 else { return }
        lastWidth = newSize.width
        onWidthChange?()
    }
}

struct HTMLBody: View {
    let inbox: InboxState
    let card: OpenMessage
    let html: String
    let inlineImages: [String: String]
    let allowRemote: Bool
    @State private var height = Tokens.TextStyle.mailBody.lineHeight

    private var theme: HTMLTheme {
        let colors = Colors.light
        return HTMLTheme(text: colors.sheetInk, secondary: colors.sheetInkTertiary, line: colors.sheetLine, background: colors.sheet,
                         fontSize: Tokens.TextStyle.mailBody.size, lineHeight: Tokens.TextStyle.mailBody.lineHeight / Tokens.TextStyle.mailBody.size, quoteBar: Tokens.Size.quoteBarWidth,
                         quoteGap: Tokens.Spacing.step12, tileWell: colors.sheetWell, tileInk: colors.mark, tileTextSize: Tokens.TextSize.small,
                         tileStripe: Tokens.Size.imageTileStripe, tileRatio: Tokens.Ratio.imageTile, tileRadius: Tokens.Radius.notice,
                         tileGap: Tokens.Spacing.step8)
    }

    private var shown: String {
        allowRemote ? html : HTMLEngine.blockingImages(html, label: String(localized: String.LocalizationValue("mail.image.blocked")))
    }

    var body: some View {
        WebBody(
            document: HTMLEngine.document(shown, theme: theme),
            inlineImages: inlineImages,
            allowRemote: allowRemote,
            load: { [inbox, id = card.id] attachment in await inbox.attachmentData(id, attachmentID: attachment) },
            compose: { [inbox] reference in _ = inbox.composeLink(reference) },
            height: $height
        )
        .frame(height: CGFloat(height))
        .frame(maxWidth: .infinity)
    }
}

struct WebBody: NSViewRepresentable {
    let document: String
    let inlineImages: [String: String]
    let allowRemote: Bool
    let load: @MainActor (String) async -> Data?
    let compose: @MainActor (String) -> Void
    @Binding var height: Double

    private static let transparentKey = "drawsBackground"

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        config.websiteDataStore = .nonPersistent()
        config.setURLSchemeHandler(context.coordinator, forURLScheme: HTMLEngine.inlineScheme)
        let view = MessageWebView(frame: .zero, configuration: config)
        view.onWidthChange = { [weak coordinator = context.coordinator] in coordinator?.measure() }
        view.navigationDelegate = context.coordinator
        view.setValue(false, forKey: Self.transparentKey)
        view.allowsMagnification = false
        context.coordinator.webView = view
        context.coordinator.apply(self)
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        context.coordinator.apply(self)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKURLSchemeHandler {
        var parent: WebBody
        weak var webView: WKWebView?
        private var shown: String?
        private var shownRemote: Bool?
        private var ruleList: WKContentRuleList?
        private var tasks: [ObjectIdentifier: Task<Void, Never>] = [:]
        private var pending: Task<Void, Never>?

        init(_ parent: WebBody) {
            self.parent = parent
            super.init()
        }

        func apply(_ next: WebBody) {
            parent = next
            guard let webView, shown != next.document || shownRemote != next.allowRemote else { return }
            shown = next.document
            shownRemote = next.allowRemote
            let controller = webView.configuration.userContentController
            controller.removeAllContentRuleLists()
            pending?.cancel()
            if next.allowRemote {
                webView.loadHTMLString(next.document, baseURL: nil)
                return
            }
            let blocked = next.document
            pending = Task { [weak self, weak webView] in
                let list = await self?.rules()
                guard self != nil, let webView, !Task.isCancelled else { return }
                if let list { webView.configuration.userContentController.add(list) }
                webView.loadHTMLString(blocked, baseURL: nil)
            }
        }

        private func rules() async -> WKContentRuleList? {
            if let ruleList { return ruleList }
            let list = try? await WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: HTMLEngine.ruleListID, encodedContentRuleList: HTMLEngine.blockRemoteRules)
            ruleList = list
            return list
        }

        func measure() {
            guard let webView else { return }
            webView.evaluateJavaScript(HTMLEngine.measureScript) { [weak self] value, _ in
                MainActor.assumeIsolated {
                    guard let self, let number = value as? NSNumber else { return }
                    let next = number.doubleValue
                    if abs(self.parent.height - next) > 1 { self.parent.height = next }
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            measure()
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            let url = navigationAction.request.url
            let verdict = HTMLEngine.navigation(
                scheme: url?.scheme,
                linkActivated: navigationAction.navigationType == .linkActivated,
                mainFrame: navigationAction.targetFrame?.isMainFrame != false)
            if verdict == .open, let url { NSWorkspace.shared.open(url) }
            if verdict == .compose, let url { parent.compose(url.absoluteString) }
            decisionHandler(verdict == .allow ? .allow : .cancel)
        }

        func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
            guard let url = urlSchemeTask.request.url,
                  let source = HTMLEngine.inlineSource(url.absoluteString, in: parent.inlineImages) else {
                urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
                return
            }
            switch source {
            case .embedded(let data, let mime):
                finish(urlSchemeTask, url: url, data: data, mime: mime)
            case .attachment(let id):
                let key = ObjectIdentifier(urlSchemeTask)
                let loader = parent.load
                tasks[key] = Task { [weak self] in
                    let data = await loader(id)
                    guard let self, self.tasks[key] != nil else { return }
                    self.tasks[key] = nil
                    guard let data else {
                        urlSchemeTask.didFailWithError(URLError(.resourceUnavailable))
                        return
                    }
                    self.finish(urlSchemeTask, url: url, data: data, mime: HTMLEngine.mimeType(of: data))
                }
            }
        }

        func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
            let key = ObjectIdentifier(urlSchemeTask)
            tasks[key]?.cancel()
            tasks[key] = nil
        }

        private func finish(_ task: any WKURLSchemeTask, url: URL, data: Data, mime: String) {
            task.didReceive(URLResponse(url: url, mimeType: mime, expectedContentLength: data.count, textEncodingName: nil))
            task.didReceive(data)
            task.didFinish()
            measure()
        }
    }
}

struct AttachmentRow: View {
    @Environment(\.appearance) private var appearance
    let session: AppSession
    let card: OpenMessage
    let row: AttachmentEntry
    @State private var hovering = false
    @State private var anchor = AnchorBox()

    var body: some View {
        HStack(spacing: CGFloat(Tokens.Spacing.step12)) {
            Glyph(.doc)
                .foregroundStyle(appearance.color(\.sheetInkTertiary))
                .frame(width: CGFloat(Tokens.Size.symbolSize), height: CGFloat(Tokens.Size.symbolSize))
                .overlay(RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.notice))
                    .strokeBorder(appearance.color(\.sheetLineStrong), lineWidth: CGFloat(Tokens.Size.hairline)))
            Text(verbatim: PersonName.middle(row.name, limit: SheetValues.attachmentNameLimit))
                .font(.face(Tokens.TextSize.body, weight: Tokens.Weight.medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .help(Text(verbatim: row.name))
            Text(verbatim: row.size)
                .font(.face(Tokens.TextSize.small))
                .foregroundStyle(appearance.color(\.sheetInkTertiary))
                .fixedSize()
            Spacer(minLength: 0)
            Glyph.small(.chevron).foregroundStyle(appearance.color(\.sheetInkTertiary))
        }
        .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
        .frame(height: CGFloat(Tokens.Spacing.step40))
        .background(Capsule().fill(hovering ? appearance.color(\.sheetWell) : Color.clear))
        .contentShape(Capsule())
        .help(Text(verbatim: row.name))
        .background(AnchorMarker(box: anchor))
        .onHover { hovering = $0 }
        .onTapGesture { menu() }
    }

    private func menu() {
        let entries = MenuLine.entries(MenuEngine.attachment(name: row.name, project: session.inbox.offersProjectFiles), appearance: appearance) { action in
            switch action {
            case .preview: run { AttachmentPreview.show($0, name: row.name) }
            case .print: run { AttachmentExport.printAttachment($0, name: row.name) }
            case .pdf: run { AttachmentExport.savePDF($0, name: row.name) }
            case .saveAs: run { AttachmentExport.save($0, name: row.name) }
            case .otherProject:
                ProjectFolderList.save(session, appearance: appearance, message: card.id, attachment: row, anchor: anchor)
            default: break
            }
        }
        anchor.showMenu(entries)
    }

    private func run(_ work: @escaping @MainActor (Data) -> Bool) {
        let inbox = session.inbox
        let id = card.id
        let attachment = row.id
        Task {
            guard let data = await inbox.attachmentData(id, attachmentID: attachment) else { return }
            if !work(data) { inbox.announce(.attachmentFailed) }
        }
    }
}

@MainActor
final class AttachmentPreview: NSObject, @preconcurrency QLPreviewPanelDataSource {
    static let shared = AttachmentPreview()
    private var file: URL?

    static func show(_ data: Data, name: String) -> Bool {
        shared.discard()
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = folder.appendingPathComponent((name as NSString).lastPathComponent)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: url)
        } catch {
            try? FileManager.default.removeItem(at: folder)
            return false
        }
        shared.file = url
        guard let panel = QLPreviewPanel.shared() else { return false }
        panel.dataSource = shared
        panel.reloadData()
        panel.makeKeyAndOrderFront(nil)
        return true
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        file == nil ? 0 : 1
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        file.map { $0 as NSURL }
    }

    func discard() {
        guard let file else { return }
        self.file = nil
        try? FileManager.default.removeItem(at: file.deletingLastPathComponent())
    }
}

@MainActor
enum AttachmentExport {
    static func pdf(_ data: Data, name: String) -> Data? {
        switch (name as NSString).pathExtension.lowercased() {
        case "pdf":
            return data
        case "txt":
            let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
            let info = NSPrintInfo.shared
            return MessagePDF.render(text: text, page: info.paperSize, margin: info.leftMargin)
        default:
            guard let image = NSImage(data: data), let page = PDFPage(image: image) else { return nil }
            let document = PDFDocument()
            document.insert(page, at: 0)
            return document.dataRepresentation()
        }
    }

    static func printAttachment(_ data: Data, name: String) -> Bool {
        guard let document = pdf(data, name: name) else { return false }
        return MessageExport.printPDF(document, name: name, scaling: .pageScaleDownToFit)
    }

    static func savePDF(_ data: Data, name: String) -> Bool {
        guard let document = pdf(data, name: name) else { return false }
        let panel = NSSavePanel()
        panel.appearance = ForeignContent.panel
        panel.allowedContentTypes = [.pdf]
        panel.isExtensionHidden = false
        panel.canSelectHiddenExtension = true
        panel.nameFieldStringValue = ((name as NSString).deletingPathExtension as NSString).appendingPathExtension("pdf") ?? name
        guard panel.runModal() == .OK, let url = panel.url else { return true }
        return (try? document.write(to: url)) != nil
    }

    static func save(_ data: Data, name: String) -> Bool {
        let panel = NSSavePanel()
        panel.appearance = ForeignContent.panel
        let type = UTType(filenameExtension: (name as NSString).pathExtension)
        if let type { panel.allowedContentTypes = [type] }
        panel.allowsOtherFileTypes = true
        panel.isExtensionHidden = false
        panel.canSelectHiddenExtension = true
        panel.nameFieldStringValue = name
        guard panel.runModal() == .OK, let url = panel.url else { return true }
        return (try? data.write(to: url)) != nil
    }
}

struct AddressButton<Label: View>: View {
    @Environment(\.appearance) private var appearance
    var capsule = false
    let action: () -> Void
    @ViewBuilder let label: Label
    @State private var hovering = false

    var body: some View {
        if capsule {
            Button(action: action) {
                label
                    .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
                    .frame(height: CGFloat(Tokens.Spacing.step28))
                    .background(Capsule().fill(hovering ? appearance.color(\.hover) : Color.clear))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.leading, -CGFloat(Tokens.Spacing.step8))
            .onHover { hovering = $0 }
        } else {
            Button(action: action) { label }
                .buttonStyle(.plain)
        }
    }
}
