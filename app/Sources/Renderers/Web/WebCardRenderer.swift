import ALFAcolorCore
import CoreGraphics
import Foundation
import ImageIO
import WebKit

/// A card running in a web page. The page shows its errors, and the errors are also kept here.
@available(macOS 26.0, *)
@MainActor
public final class LiveCard {
    /// Most errors kept. The oldest go first.
    static let keptErrors = 20

    public let page: WebPage
    public private(set) var errors: [String] = []

    init(page: WebPage) {
        self.page = page
    }

    func record(_ text: String) {
        errors.append(text)
        if errors.count > Self.keptErrors {
            errors.removeFirst(errors.count - Self.keptErrors)
        }
    }
}

/// Runs and draws web code: HTML, CSS, JavaScript, Tailwind and React.
@available(macOS 26.0, *)
@MainActor
public final class WebCardRenderer: CardRenderer {
    static let languages: Set<CodeLanguage> = [.html, .css, .javascript, .tailwind, .react]
    static let ruleListIdentifier = "card-hosts-1"

    public init() {}

    public func canRender(_ card: CodeCard) -> Bool {
        Self.languages.contains(card.language)
    }

    public func makeLive(_ card: CodeCard) async throws -> LiveCard {
        guard let html = WebDocument.html(for: card) else { throw CardRendererError.noLiveForm }
        var configuration = try await Self.configuration()
        configuration.defaultNavigationPreferences.allowsContentJavaScript = true
        let channel = CardErrorChannel()
        configuration.userContentController.add(channel, contentWorld: .page, name: WebDocument.errorChannel)
        let page = WebPage(configuration: configuration, navigationDecider: HostGuard())
        let live = LiveCard(page: page)
        channel.owner = live
        page.load(html: html)
        return live
    }

    /// A still image of the card, taken when the page has loaded. Scripts run, but a React card may not be rendered yet.
    public func snapshot(_ card: CodeCard, width: Double) async -> CGImage? {
        guard let html = WebDocument.html(for: card),
              var configuration = try? await Self.configuration() else { return nil }
        configuration.defaultNavigationPreferences.allowsContentJavaScript = true
        let page = WebPage(configuration: configuration, navigationDecider: HostGuard())
        do {
            for try await event in page.load(html: html) {
                if event == .finished { break }
            }
            let data = try await page.exported(as: .image(snapshotWidth: width))
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
            return CGImageSourceCreateImageAtIndex(source, 0, nil)
        } catch {
            return nil
        }
    }

    /// A configuration without storage on disk, with the network rules installed.
    static func configuration() async throws -> WebPage.Configuration {
        var configuration = WebPage.Configuration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(try await compiledRules())
        return configuration
    }

    static func compiledRules() async throws -> WKContentRuleList {
        try await withCheckedThrowingContinuation { continuation in
            WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: ruleListIdentifier,
                encodedContentRuleList: WebHostRule.contentRules
            ) { list, error in
                if let list {
                    continuation.resume(returning: list)
                } else {
                    continuation.resume(throwing: CardRendererError.ruleListFailed(error?.localizedDescription ?? "no list"))
                }
            }
        }
    }
}

/// Allows navigation only to the hosts on the allow list. Requests from the page are blocked by the content rules.
@available(macOS 26.0, *)
@MainActor
struct HostGuard: WebPage.NavigationDeciding {
    mutating func decidePolicy(for action: WebPage.NavigationAction, preferences: inout WebPage.NavigationPreferences) async -> WKNavigationActionPolicy {
        guard let url = action.request.url, WebHostRule.allows(url) else { return .cancel }
        return .allow
    }
}
