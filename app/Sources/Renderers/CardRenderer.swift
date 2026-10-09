import ALFAcolorCore
import CoreGraphics

/// The code of one code card: its language and its files by name.
public struct CodeCard: Equatable, Sendable {
    public var language: CodeLanguage
    public var files: [String: String]

    public init(language: CodeLanguage, files: [String: String]) {
        self.language = language
        self.files = files
    }
}

/// Runs or draws the code of cards in one family of languages.
@available(macOS 26.0, *)
@MainActor
public protocol CardRenderer {
    /// Whether this renderer takes the card.
    func canRender(_ card: CodeCard) -> Bool
    /// A running form of the card. Throws when the card has no running form.
    func makeLive(_ card: CodeCard) async throws -> LiveCard
    /// A still image of the card at `width` points. Throws when the card cannot be drawn.
    func snapshot(_ card: CodeCard, width: Double) async throws -> CGImage
}

public enum CardRendererError: Error, Equatable {
    /// The renderer has no running form for this card.
    case noLiveForm
    /// WebKit did not compile the network rules. The message comes from WebKit.
    case ruleListFailed(String)
    /// A React card did not draw its component in time. Its scripts may not have loaded.
    case notDrawn
    /// The card did not load, draw or export in time. Its page was released.
    case timedOut
    /// The page could not be loaded because of the network. Only this error is asked again.
    case network(String)
}

/// Renderers in the order they were registered. The first one that takes a card serves it.
@available(macOS 26.0, *)
@MainActor
public final class CardRendererRegistry {
    private var renderers: [any CardRenderer] = []

    public init() {}

    public func register(_ renderer: any CardRenderer) {
        renderers.append(renderer)
    }

    public func renderer(for card: CodeCard) -> (any CardRenderer)? {
        renderers.first { $0.canRender(card) }
    }
}
