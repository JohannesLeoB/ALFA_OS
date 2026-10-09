import BoardModel
import ALFAcolorCore
import Observation
import Renderers

/// The lab of one code card: its session, its running page, and the link to the card on the board.
/// The model lives as long as the window, so the draft stays when the lab closes.
@MainActor
@Observable
final class LabModel {
    /// What stopped the last change of the card.
    enum Problem: Equatable {
        case empty, notSaved

        var key: String {
            switch self {
            case .empty: "lab.problem.empty"
            case .notSaved: "lab.problem.notSaved"
            }
        }
    }

    let item: ItemID
    @ObservationIgnored private let store: BoardStore
    @ObservationIgnored private var pending: Task<Void, Never>?
    private(set) var session: LabSession
    /// The running page. nil while the page is not built.
    private(set) var live: LiveCard?
    private(set) var problem: Problem?

    /// The lab of a card that is web code on the board. nil for any other item.
    init?(item: ItemID, store: BoardStore) {
        guard let draft = LabModel.boardDraft(item, in: store) else { return nil }
        self.item = item
        self.store = store
        session = LabSession(draft: draft)
    }

    /// The card's draft as it is on the board. nil when the item is gone or is not web code.
    static func boardDraft(_ id: ItemID, in store: BoardStore) -> LabDraft? {
        guard let item = store.item(id), case .code(let language, let files, let width) = item.content else { return nil }
        return LabDraft(card: CodeCard(language: language, files: files), previewWidth: width)
    }

    // MARK: - Page

    /// Builds the page from the session, replacing a running one.
    func reloadPage() async {
        live = nil
        guard let document = LabPreview.document(for: session.draft, controls: session.controls, dark: session.isDark) else { return }
        live = try? await LabPreview.makeLive(document)
    }

    /// Ends the running page. The draft stays in the model.
    func stopPage() {
        pending?.cancel()
        pending = nil
        live = nil
    }

    // MARK: - Edits

    func show(_ tab: LabDraft.Tab) {
        session.show(tab)
    }

    /// A text change rebuilds the page after a short pause, so typing does not start a page per key.
    func edit(_ text: String, in tab: LabDraft.Tab) {
        session.edit(text, in: tab)
        scheduleReload()
    }

    func paste(_ text: String) {
        session.paste(text)
        scheduleReload()
    }

    func setArt(_ art: LabDraft.Art) {
        session.setArt(art)
        scheduleReload()
    }

    func setWidth(_ width: Double) {
        session.setWidth(width)
    }

    /// A control change goes into the running page without a reload.
    func setNumber(_ number: Double, for name: String) {
        session.setNumber(number, for: name)
        takeControlsOver()
    }

    func setColour(_ hex: String, for name: String) {
        session.setColour(hex, for: name)
        takeControlsOver()
    }

    func toggleDark() {
        session.isDark.toggle()
        scheduleReload()
    }

    // MARK: - View options

    func setZoom(_ zoom: LabZoom) {
        session.zoom = zoom
    }

    func toggleGrid() {
        session.showsGrid.toggle()
    }

    func toggleGuides() {
        session.showsGuides.toggle()
    }

    func restart() {
        pending?.cancel()
        Task { await reloadPage() }
    }

    /// Writes the control values into the code and makes the result the card's newest version on the board.
    func commit() {
        problem = nil
        guard !session.draft.files.isEmpty else {
            problem = .empty
            return
        }
        let board = LabModel.boardDraft(item, in: store) ?? session.draft
        let saved = session.commit(over: board)
        do {
            let command = Command.setContent(item, .code(language: saved.language, files: saved.files, previewWidth: saved.width))
            guard try store.perform(command) else {
                problem = .notSaved
                return
            }
        } catch {
            problem = .notSaved
        }
    }

    private func scheduleReload() {
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, let self else { return }
            await self.reloadPage()
        }
    }

    private func takeControlsOver() {
        guard let live else { return }
        let controls = session.controls
        Task { await LabPreview.apply(controls, to: live) }
    }
}
