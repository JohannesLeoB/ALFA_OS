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
    /// Longest time for a still: loading, drawing and export.
    public static let defaultStillLimit = 20.0
    /// Longest wait for a React card to draw its component.
    static let drawLimit = 5.0

    private let stills: any StillHost
    private let stillLimit: Double

    /// `stillLimit` is the longest time for one still, in seconds.
    public init(stills: any StillHost = OffscreenStillHost(), stillLimit: Double = WebCardRenderer.defaultStillLimit) {
        self.stills = stills
        self.stillLimit = stillLimit
    }

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
        page.load(html: html, baseURL: WebHostRule.cardOrigin)
        return live
    }

    /// A still image of the card at `width` points. Throws `timedOut` when the page does not load, draw or export in
    /// time, `network` when the page could not be reached, and the other renderer errors when the card fails.
    public func snapshot(_ card: CodeCard, width: Double) async throws -> CGImage {
        let slot = PageSlot()
        let data: Data
        do {
            data = try await withDeadline(seconds: stillLimit) {
                let page = try await self.stillPage(card, slot: slot)
                return try await self.stills.export(page, width: width)
            }
        } catch is DeadlineExceeded {
            slot.release()
            throw CardRendererError.timedOut
        } catch {
            slot.release()
            if (error as NSError).domain == NSURLErrorDomain {
                throw CardRendererError.network(error.localizedDescription)
            }
            throw error
        }
        slot.release()
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw CardRendererError.notDrawn
        }
        return image
    }

    /// A page of the card with its scripts run, ready for a still. Throws when a React card does not draw in time.
    func stillPage(_ card: CodeCard, slot: PageSlot) async throws -> WebPage {
        guard let html = WebDocument.html(for: card) else { throw CardRendererError.noLiveForm }
        var configuration = try await Self.configuration()
        configuration.defaultNavigationPreferences.allowsContentJavaScript = true
        let page = WebPage(configuration: configuration, navigationDecider: HostGuard())
        slot.page = page
        for try await event in page.load(html: html, baseURL: WebHostRule.cardOrigin) {
            if event == .finished { break }
        }
        if card.language == .react {
            try await waitForDrawing(page)
        }
        return page
    }

    /// Polls a React page until the component is on it, or until the page shows an error.
    private func waitForDrawing(_ page: WebPage) async throws {
        for _ in 0..<Int(Self.drawLimit * 10) {
            let drawn = try? await page.callJavaScript(WebDocument.drawnCheck)
            if drawn as? Bool == true { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw CardRendererError.notDrawn
    }

    /// A configuration without storage on disk, with the shared network rules installed.
    static func configuration() async throws -> WebPage.Configuration {
        var configuration = WebPage.Configuration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(try await sharedRules())
        return configuration
    }

    /// The compiled network rules. Every page shares them.
    private static var rules: WKContentRuleList?

    static func sharedRules() async throws -> WKContentRuleList {
        if let rules { return rules }
        let list = try await compiledRules()
        rules = list
        return list
    }

    static func compiledRules() async throws -> WKContentRuleList {
        try await withCheckedThrowingContinuation { continuation in
            WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: WebHostRule.identifier,
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

/// Holds the page of a still while it is taken, so that a page that does not end can be stopped and released.
@available(macOS 26.0, *)
@MainActor
final class PageSlot {
    var page: WebPage?

    /// Stops loading and drops the page. A script that is still running stops with its page.
    func release() {
        page?.stopLoading()
        page = nil
    }
}

/// Allows navigation only to the hosts on the allow list. Requests from the page are blocked by the content rules.
@available(macOS 26.0, *)
@MainActor
struct HostGuard: WebPage.NavigationDeciding {
    mutating func decidePolicy(for action: WebPage.NavigationAction, preferences: inout WebPage.NavigationPreferences) async -> WKNavigationActionPolicy {
        guard let url = action.request.url, WebHostRule.allowsNavigation(url) else { return .cancel }
        return .allow
    }
}
