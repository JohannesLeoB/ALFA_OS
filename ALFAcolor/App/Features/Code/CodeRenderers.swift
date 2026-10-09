import BoardModel
import Renderers

/// The renderers of the canvas. A code card goes to the first renderer that takes it.
@MainActor
enum CodeRenderers {
    static let registry: CardRendererRegistry = {
        let registry = CardRendererRegistry()
        registry.register(WebCardRenderer(stills: WindowStillHost()))
        return registry
    }()

    static func card(_ content: CodeContent) -> CodeCard {
        CodeCard(language: content.language, files: content.files)
    }

    static func renderer(for content: CodeContent) -> (any CardRenderer)? {
        registry.renderer(for: card(content))
    }
}
