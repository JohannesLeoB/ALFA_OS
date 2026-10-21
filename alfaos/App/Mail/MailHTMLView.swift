import AppKit
import Mail
import ShellCore
import SwiftUI
import WebKit

final class MailWebView: WKWebView {
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

struct MailHTMLBody: View {
    let model: MailModel
    let card: ReadingCard
    let html: String
    let inlineImages: [String: String]
    let allowRemote: Bool
    @State private var height = Design.TextSize.body * Design.LineHeight.mailBody

    private var style: MailHTMLStyle {
        let colors = DesignColors.light
        return MailHTMLStyle(text: colors.sheetInk, secondary: colors.sheetInkTertiary, line: colors.sheetLine,
                             background: colors.sheet, fontSize: Design.TextSize.body, lineHeight: Design.LineHeight.mailBody,
                             quoteBar: Design.Size.quoteBarWidth, quoteGap: Design.Spacing.step12)
    }

    var body: some View {
        MailHTMLView(
            document: MailHTML.document(html, style: style),
            inlineImages: inlineImages,
            allowRemote: allowRemote,
            load: { [model, id = card.id] attachment in await model.attachmentData(id, attachmentID: attachment) },
            height: $height
        )
        .frame(height: CGFloat(height))
        .frame(maxWidth: .infinity)
    }
}

struct MailHTMLView: NSViewRepresentable {
    let document: String
    let inlineImages: [String: String]
    let allowRemote: Bool
    let load: @MainActor (String) async -> Data?
    @Binding var height: Double

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        config.websiteDataStore = .nonPersistent()
        config.setURLSchemeHandler(context.coordinator, forURLScheme: MailHTML.inlineScheme)
        let view = MailWebView(frame: .zero, configuration: config)
        view.onWidthChange = { [weak coordinator = context.coordinator] in coordinator?.measure() }
        view.navigationDelegate = context.coordinator
        view.setValue(false, forKey: "drawsBackground")
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
        var parent: MailHTMLView
        weak var webView: WKWebView?
        private var shown: String?
        private var shownRemote: Bool?
        private var ruleList: WKContentRuleList?
        private var tasks: [ObjectIdentifier: Task<Void, Never>] = [:]
        private var pending: Task<Void, Never>?

        init(_ parent: MailHTMLView) {
            self.parent = parent
            super.init()
        }

        func apply(_ next: MailHTMLView) {
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
            pending = Task { [weak self, weak webView] in
                let list = await self?.rules()
                guard let self, let webView, !Task.isCancelled else { return }
                if let list { webView.configuration.userContentController.add(list) }
                if list != nil { webView.loadHTMLString(self.parent.document, baseURL: nil) }
            }
        }

        private func rules() async -> WKContentRuleList? {
            if let ruleList { return ruleList }
            let list = try? await WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: MailHTML.ruleListID, encodedContentRuleList: MailHTML.blockRemoteRules)
            ruleList = list
            return list
        }

        func measure() {
            guard let webView else { return }
            webView.evaluateJavaScript("Math.ceil(document.body.getBoundingClientRect().height)") { [weak self] value, _ in
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
            let verdict = MailHTML.navigation(
                scheme: url?.scheme,
                linkActivated: navigationAction.navigationType == .linkActivated,
                mainFrame: navigationAction.targetFrame?.isMainFrame != false)
            if verdict == .open, let url { NSWorkspace.shared.open(url) }
            decisionHandler(verdict == .allow ? .allow : .cancel)
        }

        func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
            guard let url = urlSchemeTask.request.url,
                  let source = MailHTML.inlineSource(url.absoluteString, in: parent.inlineImages) else {
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
                    self.finish(urlSchemeTask, url: url, data: data, mime: MailHTML.mimeType(of: data))
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
