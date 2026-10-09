import BoardModel
import CoreGraphics
import Foundation
import Observation
import Renderers

/// One code card on the canvas: its state, its live page while it plays, and its still image while it rests.
/// The page and the image belong to the window, not to the document.
@MainActor
@Observable
final class CodeCardModel {
    /// Names the card among the live players.
    private let id = UUID()
    private(set) var content: CodeContent
    private(set) var state: CodeCardState
    private(set) var live: LiveCard?
    private(set) var still: CGImage?
    /// Why the page did not start. nil when it started or has not failed.
    private(set) var failure: String?
    /// The content that the still image was made from.
    private var stillSource: CodeContent?
    /// Times the still was asked again after a failure, in a row.
    private var retries = 0
    /// True while the page is being built, so a second press does not build another page.
    private var starting = false
    private let players: CodePlayers
    private let stills: CodeStills

    static let maxRetries = 5
    static let retryDelay = Duration.seconds(30)

    init(content: CodeContent, players: CodePlayers = .shared, stills: CodeStills = .shared) {
        self.content = content
        self.players = players
        self.stills = stills
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
        stopLive()
        state.rest()
        retries = 0
    }

    func show(_ view: CodeView) {
        state.show(view)
        if !state.isLive { stopLive() }
    }

    func select(_ fileName: String) {
        state.select(fileName)
    }

    /// Starts the live page. It stays only while the card still plays the same content.
    func play() async {
        state.play()
        guard state.isLive, live == nil, !starting else { return }
        guard let renderer = CodeRenderers.renderer(for: content) else {
            state.rest()
            return
        }
        let source = content
        starting = true
        defer { starting = false }
        do {
            let page = try await renderer.makeLive(CodeRenderers.card(source))
            guard state.isLive, content == source, live == nil else { return }
            players.claim(id) { [weak self] in self?.rest() }
            live = page
            failure = nil
        } catch {
            state.rest()
            failure = String(describing: error)
        }
    }

    func rest() {
        state.rest()
        stopLive()
    }

    /// Makes the still image of the current content, unless the image already shows it.
    /// A failed still is asked again later, a few times.
    func refreshStill() async {
        guard let source = stillRequest, source != stillSource,
              let renderer = CodeRenderers.renderer(for: source) else { return }
        let image = await stills.still(for: CodeRenderers.card(source), width: CodeCardLayout.pageWidth(previewWidth: source.previewWidth), renderer: renderer)
        guard stillRequest == source else { return }
        still = image
        if image == nil {
            scheduleRetry()
        } else {
            stillSource = source
            retries = 0
        }
    }

    private func stopLive() {
        live = nil
        players.release(id)
    }

    private func scheduleRetry() {
        guard retries < Self.maxRetries else { return }
        retries += 1
        Task { [weak self] in
            try? await Task.sleep(for: Self.retryDelay)
            await self?.refreshStill()
        }
    }
}
