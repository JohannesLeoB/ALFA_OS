import BoardModel
import ALFAcolorCore
import Document
import Observation
import CodePlayer

/// The lab of one code card: its session, its running page, and the link to the card on the board.
/// The model lives as long as the window, so the draft stays when the lab closes.
@MainActor
@Observable
final class LabModel {
    /// The result of the last commit, or the reason why it did not run.
    enum Message: Equatable {
        case empty, notSaved, locked, unchanged, saved, rebuilt, tooLarge

        var key: String {
            switch self {
            case .empty: "lab.problem.empty"
            case .notSaved: "lab.problem.notSaved"
            case .locked: "lab.problem.locked"
            case .unchanged: "lab.problem.unchanged"
            case .saved: "lab.saved"
            case .rebuilt: "lab.rebuilt"
            case .tooLarge: "lab.problem.tooLarge"
            }
        }

        /// True for a result that the user must act on. Saved and unchanged are not problems.
        var isProblem: Bool {
            switch self {
            case .empty, .notSaved, .locked, .rebuilt, .tooLarge: true
            case .unchanged, .saved: false
            }
        }
    }

    let item: ItemID
    @ObservationIgnored private let store: BoardStore
    @ObservationIgnored private var pending: Task<Void, Never>?
    /// The card as the lab last saw it on the board. A board that differs from it has changed since.
    @ObservationIgnored private var seen: LabDraft
    /// The versions of the card as the lab last saw them. Versions that change on the document reopen the lab.
    @ObservationIgnored private var seenVersions: [CardVersion]
    private(set) var session: LabSession
    /// The running page. nil while the page is not built.
    private(set) var live: LiveCard?
    private(set) var message: Message?

    /// The lab of a card that is web code on the board. nil for any other item.
    init?(item: ItemID, store: BoardStore) {
        guard let draft = LabModel.boardDraft(item, in: store) else { return nil }
        self.item = item
        self.store = store
        self.seen = draft
        self.seenVersions = store.document.versions.versions(of: item)
        session = LabSession(draft: draft, older: LabModel.history(of: item, in: store))
    }

    /// The earlier versions of the card as lab drafts, oldest first. They come from the document.
    static func history(of id: ItemID, in store: BoardStore) -> [LabDraft] {
        store.document.versions.versions(of: id).compactMap { version in
            LabDraft(card: CodeCard(language: version.language, files: version.files), previewWidth: nil)
        }
    }

    /// The card's draft as it is on the board. nil when the item is gone or is not web code.
    static func boardDraft(_ id: ItemID, in store: BoardStore) -> LabDraft? {
        guard let board = boardCard(id, in: store) else { return nil }
        return LabDraft(card: board.card, previewWidth: board.width)
    }

    /// The files, the language and the width of the card as it is on the board.
    static func boardCard(_ id: ItemID, in store: BoardStore) -> (card: CodeCard, width: Double?)? {
        guard let item = store.item(id), case .code(let language, let files, let width) = item.content else { return nil }
        return (CodeCard(language: language, files: files), width)
    }

    /// False when the card changed on the board since the lab last saw it, for example after an undo.
    func isCurrent(in store: BoardStore) -> Bool {
        LabModel.boardDraft(item, in: store) == seen && store.document.versions.versions(of: item) == seenVersions
    }

    // MARK: - Page

    /// Builds the page from the session, replacing a running one.
    func reloadPage() async {
        live = nil
        // Code that does not run never becomes a page, so its source cannot show as text.
        guard session.blocked == nil else { return }
        guard let document = LabPreview.document(for: session.draft, controls: session.controls, props: session.props, dark: session.isDark) else { return }
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
        message = nil
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

    /// A property control goes into the running page without a reload.
    func setProp(_ value: LabProp.Value, for name: String) {
        session.setProp(value, for: name)
        takePropsOver()
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
    /// The card keeps its file names and language, and a card that is locked is not changed.
    func commit() {
        message = nil
        guard !session.draft.files.isEmpty else {
            message = .empty
            return
        }
        guard !isLocked, let board = LabModel.boardCard(item, in: store),
              let boardDraft = LabDraft(card: board.card, previewWidth: board.width) else {
            message = .locked
            return
        }
        // The card changed on the board since the lab last saw it, for example after an undo.
        // The old draft must not be written back, so the lab takes the card again.
        // A draft with unsaved text is kept as a version first, so the rebuild loses nothing.
        if boardDraft != seen {
            let pending = LabWriteBack.applyProps(session.props, to: LabWriteBack.apply(session.controls, to: session.draft))
            if pending != seen {
                let draftCard = pending.card(over: board.card)
                do {
                    try store.keepDraftVersion(of: item, language: draftCard.language, files: draftCard.files)
                } catch VersionError.tooLarge {
                    message = .tooLarge
                    return
                } catch {
                    message = .notSaved
                    return
                }
                seenVersions = store.document.versions.versions(of: item)
            }
            session.reset(to: boardDraft)
            seen = boardDraft
            message = .rebuilt
            restart()
            return
        }
        let saved = session.commit(over: boardDraft)
        let card = saved.card(over: board.card)
        guard card != board.card || saved.width != boardDraft.width else {
            message = .unchanged
            return
        }
        do {
            // The lab saves the code and keeps the code before it as a version, in one undo step.
            guard try store.saveLabCode(of: item, language: card.language, files: card.files, width: saved.width) else {
                message = .notSaved
                return
            }
            seen = LabModel.boardDraft(item, in: store) ?? saved
            seenVersions = store.document.versions.versions(of: item)
            message = .saved
        } catch VersionError.tooLarge {
            message = .tooLarge
        } catch {
            message = .notSaved
        }
    }

    /// The card is locked when the item or its layer is locked.
    private var isLocked: Bool {
        guard let card = store.item(item), let space = store.activeSpace else { return true }
        return card.locked || space.layers.contains { $0.id == card.layerID && $0.locked }
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

    private func takePropsOver() {
        guard let live else { return }
        let props = session.props
        Task { await LabPreview.applyProps(props, to: live) }
    }
}
