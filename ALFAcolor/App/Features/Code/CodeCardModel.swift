import BoardModel
import CoreGraphics
import Observation
import Renderers

/// One code card on the canvas: its state, its live page while it plays, and its still image while it rests.
/// The page and the image belong to the window, not to the document.
@MainActor
@Observable
final class CodeCardModel {
    private(set) var content: CodeContent
    private(set) var state: CodeCardState
    private(set) var live: LiveCard?
    private(set) var still: CGImage?
    /// The content that the still image was made from.
    private var stillSource: CodeContent?

    init(content: CodeContent) {
        self.content = content
        self.state = CodeCardState(fileNames: Array(content.files.keys), canPlay: CodeRenderers.renderer(for: content) != nil)
    }

    /// The content while the player rests and needs a still image. nil while the page plays or the source shows.
    var stillRequest: CodeContent? {
        state.isResting ? content : nil
    }

    /// The width of the page in points.
    var pageWidth: Double {
        CodeCardLayout.pageWidth(previewWidth: content.previewWidth)
    }

    /// Takes new content after an edit. A page that runs the old code stops.
    func update(_ new: CodeContent) {
        guard new != content else { return }
        content = new
        state.update(fileNames: Array(new.files.keys), canPlay: CodeRenderers.renderer(for: new) != nil)
        live = nil
        state.rest()
    }

    func show(_ view: CodeView) {
        state.show(view)
        if !state.isLive { live = nil }
    }

    func select(_ fileName: String) {
        state.select(fileName)
    }

    /// Starts the live page. It stays only while the card still plays the same content.
    func play() async {
        state.play()
        guard state.isLive, live == nil else { return }
        guard let renderer = CodeRenderers.renderer(for: content) else {
            state.rest()
            return
        }
        let source = content
        do {
            let page = try await renderer.makeLive(CodeRenderers.card(source))
            guard state.isLive, content == source else { return }
            live = page
        } catch {
            state.rest()
        }
    }

    func rest() {
        state.rest()
        live = nil
    }

    /// Makes the still image of the current content, unless the image already shows it.
    func refreshStill() async {
        guard let source = stillRequest, source != stillSource,
              let renderer = CodeRenderers.renderer(for: source) else { return }
        let image = await renderer.snapshot(CodeRenderers.card(source), width: CodeCardLayout.pageWidth(previewWidth: source.previewWidth))
        guard stillRequest == source else { return }
        still = image
        stillSource = source
    }
}
