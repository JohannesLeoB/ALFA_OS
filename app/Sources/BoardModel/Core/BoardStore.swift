import Foundation
import Observation
import ALFAcolorCore
import Document

/// The state of the canvas: the document, the active space, the selection and the view of each space.
/// All changes to the document go through `perform(_:)` and can be undone.
/// The views read this state and never change the document by themselves.
@MainActor
@Observable
public final class BoardStore {
    public private(set) var document: ALFAcolorDocument
    public private(set) var activeSpaceID: String?
    public private(set) var selection: Set<ItemID> = []
    /// The view of each space by space ID. Not part of the document and not undone; the file keeps it on save.
    public private(set) var viewports: [String: Viewport] = [:]
    /// Counts every change of the document, including undo and redo.
    public private(set) var revision = 0
    /// Where the document stands against the file. Updated on every change and save.
    public private(set) var saveState: SaveState = .saved
    /// The error of the last save, nil after a successful save.
    public private(set) var lastSaveError: (any Error)?

    /// The document as the file holds it. nil for a new document that was never saved.
    @ObservationIgnored private var savedDocument: ALFAcolorDocument?

    /// Called with the document and its revision after every change of the document (on the main actor).
    @ObservationIgnored public var onChange: ((ALFAcolorDocument, Int) -> Void)?
    /// Called when a view or the active space changes. Such a change is not a change of the document.
    @ObservationIgnored public var onViewChange: (() -> Void)?
    /// Called before the active space changes, while the space being left is still active.
    @ObservationIgnored public var onWillSwitchSpace: (() -> Void)?
    /// A value typed into an inspector field that is not applied yet. It is applied before the active space changes,
    /// so that it reaches the items of the space being left.
    @ObservationIgnored public var pendingDraft: (() -> Void)?

    @ObservationIgnored public private(set) var undoManager: UndoManager

    /// Without `undoManager` the store makes its own, which closes one undo step per command.
    /// A manager from the window keeps its own grouping rules, so one command is one step only when
    /// every command runs in its own pass of the event loop.
    /// `isSaved` is false for a new document. The views and the active space come from the file.
    public init(document: ALFAcolorDocument, undoManager: UndoManager? = nil, isSaved: Bool = true) {
        self.document = document
        if let undoManager {
            self.undoManager = undoManager
        } else {
            let own = UndoManager()
            own.groupsByEvent = false
            self.undoManager = own
        }
        let spaceIDs = Set(document.board.spaces.map(\.id))
        viewports = document.spaceViews.filter { spaceIDs.contains($0.key) && $0.value.isValid }
            .mapValues { Viewport(zoom: $0.zoom, offsetX: $0.offsetX, offsetY: $0.offsetY) }
        if let saved = document.activeSpaceID, spaceIDs.contains(saved) {
            activeSpaceID = saved
        } else {
            activeSpaceID = document.board.spaces.first?.id
        }
        savedDocument = isSaved ? document : nil
        refreshSaveState()
    }

    // MARK: Reading

    public var board: Board { document.board }

    public var activeSpace: Space? {
        guard let id = activeSpaceID else { return nil }
        return document.board.spaces.first { $0.id == id }
    }

    public func item(_ id: ItemID) -> Item? { activeSpace?.items.first { $0.id == id } }

    /// The selected items that can be seen. A hidden item never counts as selected.
    public var selectedItems: [Item] {
        guard let space = activeSpace else { return [] }
        let seen = Self.visibleIDs(in: space)
        return space.items.filter { selection.contains($0.id) && seen.contains($0.id) }
    }

    /// The IDs of the items that can be seen: not hidden, and not on a hidden layer.
    static func visibleIDs(in space: Space) -> Set<ItemID> {
        let hiddenLayers = Set(space.layers.filter { !$0.visible }.map(\.id))
        return Set(space.items.filter { !$0.hidden && !hiddenLayers.contains($0.layerID) }.map(\.id))
    }

    /// The selection without the items that cannot be seen in the active space.
    private func visibleSelection(_ ids: Set<ItemID>) -> Set<ItemID> {
        guard let space = activeSpace else { return [] }
        return ids.intersection(Self.visibleIDs(in: space))
    }

    // MARK: Commands

    /// Runs a command. Returns true when it changed the document or the active space.
    /// A command that fails changes nothing. Every command except `switchSpace` is one undo step.
    @discardableResult
    public func perform(_ command: Command) throws -> Bool {
        if case .switchSpace(let id) = command { return try switchSpace(to: id) }
        guard let spaceID = activeSpaceID else { throw CommandError.noActiveSpace }
        var trial = document.board
        guard let edit = try command.apply(to: &trial, spaceID: spaceID, selection: selection) else { return false }
        document.board = trial
        selection = visibleSelection(edit.selectionAfter)
        didChangeDocument()
        register(edit, name: command.undoName)
        return true
    }

    /// Stores the bytes of an image file in the document and returns the asset ID (the hash of the bytes).
    /// It is no undo step. The file is saved with the document even when nothing refers to it yet.
    /// A command that refers to the ID, for example `setContent`, is the change.
    @discardableResult
    public func addAsset(_ data: Data, fileExtension: String) -> String {
        let id = document.assets.add(data, fileExtension: fileExtension)
        onChange?(document, revision)
        refreshSaveState()
        return id
    }

    private func switchSpace(to id: String) throws -> Bool {
        guard document.board.spaces.contains(where: { $0.id == id }) else { throw CommandError.unknownSpace(id) }
        guard id != activeSpaceID else { return false }
        let draft = pendingDraft
        pendingDraft = nil
        draft?()
        onWillSwitchSpace?()
        activeSpaceID = id
        selection = []
        onViewChange?()
        return true
    }

    // MARK: Board changes (rooms, layers)

    /// Changes the board as a whole, for example rooms, layers or items moved between rooms.
    /// The change runs on a copy: when it throws, nothing changes. It is one undo step, named by `nameKey`.
    /// Returns false when nothing changed.
    @discardableResult
    public func changeBoard(nameKey: String, _ change: (inout Board) throws -> Void) throws -> Bool {
        // Ends a text edit or a drag first: its text must land in the room it was typed in, before a room can vanish.
        onWillSwitchSpace?()
        var trial = document.board
        try change(&trial)
        guard trial != document.board else { return false }
        swapBoard(to: trial, nameKey: nameKey)
        return true
    }

    /// Puts another board in place. The active room stays if it still exists, else the first room is active.
    private func swapBoard(to target: Board, nameKey: String) {
        let previous = document.board
        document.board = target
        if !target.spaces.contains(where: { $0.id == activeSpaceID }) { activeSpaceID = target.spaces.first?.id }
        selection = visibleSelection(selection)
        // A removed space takes its view with it; a new space with the same ID starts at zoom 1.
        let ids = Set(target.spaces.map(\.id))
        viewports = viewports.filter { ids.contains($0.key) }
        didChangeDocument()
        let inHistory = undoManager.isUndoing || undoManager.isRedoing
        if !inHistory { undoManager.beginUndoGrouping() }
        undoManager.registerUndo(withTarget: self) { store in
            MainActor.assumeIsolated { store.swapBoard(to: previous, nameKey: nameKey) }
        }
        undoManager.setActionName(Command.localized(nameKey))
        if !inHistory { undoManager.endUndoGrouping() }
    }

    // MARK: Undo

    /// Uses the undo manager of the window from now on. Steps in the previous manager stay there and no longer reach this store.
    /// Call it before the first change; the window brings its manager when it appears.
    public func useUndoManager(_ manager: UndoManager) {
        guard manager !== undoManager else { return }
        undoManager = manager
    }

    public var canUndo: Bool { undoManager.canUndo }
    public var canRedo: Bool { undoManager.canRedo }
    public func undo() { undoManager.undo() }
    public func redo() { undoManager.redo() }

    private func register(_ edit: Edit, name: String?) {
        let inHistory = undoManager.isUndoing || undoManager.isRedoing
        if !inHistory { undoManager.beginUndoGrouping() }
        undoManager.registerUndo(withTarget: self) { store in
            MainActor.assumeIsolated { store.revert(edit, name: name) }
        }
        if let name { undoManager.setActionName(name) }
        if !inHistory { undoManager.endUndoGrouping() }
    }

    /// Takes back an edit. The undo manager calls it for undo and for redo; the inverse edit is registered each time.
    private func revert(_ edit: Edit, name: String?) {
        let inverse = edit.reversed
        var trial = document.board
        guard inverse.apply(to: &trial) else { return }
        document.board = trial
        activeSpaceID = inverse.spaceID
        let existing = Set(trial.spaces.first { $0.id == inverse.spaceID }?.items.map(\.id) ?? [])
        selection = visibleSelection(inverse.selectionAfter.intersection(existing))
        didChangeDocument()
        register(inverse, name: name)
    }

    // MARK: Selection

    /// Selects the items with these IDs. IDs that are not in the active space are dropped.
    /// Items that cannot be seen (hidden, or on a hidden layer) are dropped as well.
    public func select(_ ids: Set<ItemID>) {
        selection = visibleSelection(ids)
    }

    public func toggleSelection(_ id: ItemID) {
        if selection.contains(id) { selection.remove(id) } else { select(selection.union([id])) }
    }

    public func clearSelection() { selection = [] }
    public func selectAll() { select(Set(activeSpace?.items.map(\.id) ?? [])) }

    // MARK: View

    /// The view of the active space. A space without a stored view has zoom 1 at the origin.
    public var viewport: Viewport { activeSpaceID.flatMap { viewports[$0] } ?? Viewport() }

    /// Sets the view of a space (default: the active one). A view with a zoom of zero or less, or a value that is not finite, is ignored.
    public func setViewport(_ viewport: Viewport, for spaceID: String? = nil) {
        guard viewport.isValid, let id = spaceID ?? activeSpaceID, document.board.spaces.contains(where: { $0.id == id }) else { return }
        viewports[id] = viewport
        onViewChange?()
    }

    // MARK: Saving

    /// The document was written to the file (the state `document` as it is now). Clears the save error.
    /// Called by the window after it has built the package; the store runs no save of its own.
    public func markSaved(_ saved: ALFAcolorDocument) {
        lastSaveError = nil
        savedDocument = saved
        refreshSaveState()
    }

    /// A save failed. The error stays visible until a later save works.
    public func markSaveFailed(_ error: any Error) {
        lastSaveError = error
        refreshSaveState()
    }

    private func didChangeDocument() {
        revision += 1
        onChange?(document, revision)
        refreshSaveState()
    }

    /// Works out the state from the saved document. The board, the token sets and the image IDs decide;
    /// the views and the active space are not part of the document and never mark it as changed.
    private func refreshSaveState() {
        if lastSaveError != nil {
            saveState = .failed
        } else if let savedDocument {
            saveState = Self.sameContent(savedDocument, document) ? .saved : .modified
        } else {
            saveState = .new
        }
    }

    private static func sameContent(_ a: ALFAcolorDocument, _ b: ALFAcolorDocument) -> Bool {
        a.board == b.board && a.tokenSets == b.tokenSets && Set(a.assets.ids) == Set(b.assets.ids)
    }
}
