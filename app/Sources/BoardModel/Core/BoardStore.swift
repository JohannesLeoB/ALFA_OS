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
    /// The view of each space by space ID. Not part of the document and not undone.
    public private(set) var viewports: [String: Viewport] = [:]
    /// Counts every change of the document, including undo and redo.
    public private(set) var revision = 0
    /// True from a change until the next successful save of the state that had that change.
    public private(set) var hasUnsavedChanges = false
    /// The error of the last save, nil after a successful save.
    public private(set) var lastSaveError: (any Error)?

    @ObservationIgnored public private(set) var undoManager: UndoManager
    @ObservationIgnored private let autosave: Autosave?
    @ObservationIgnored private var scheduledSave: Task<Void, Never>?
    @ObservationIgnored private var runningSave: Task<Void, any Error>?

    /// Without `undoManager` the store makes its own, which closes one undo step per command.
    /// A manager from the window keeps its own grouping rules, so one command is one step only when
    /// every command runs in its own pass of the event loop.
    public init(document: ALFAcolorDocument, undoManager: UndoManager? = nil, autosave: Autosave? = nil) {
        self.document = document
        self.autosave = autosave
        if let undoManager {
            self.undoManager = undoManager
        } else {
            let own = UndoManager()
            own.groupsByEvent = false
            self.undoManager = own
        }
        activeSpaceID = document.board.spaces.first?.id
    }

    // MARK: Reading

    public var board: Board { document.board }

    public var activeSpace: Space? {
        guard let id = activeSpaceID else { return nil }
        return document.board.spaces.first { $0.id == id }
    }

    public func item(_ id: ItemID) -> Item? { activeSpace?.items.first { $0.id == id } }

    public var selectedItems: [Item] {
        guard let space = activeSpace else { return [] }
        return space.items.filter { selection.contains($0.id) }
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
        selection = edit.selectionAfter
        didChangeDocument()
        register(edit, name: command.undoName)
        return true
    }

    /// Stores the bytes of an image file in the document and returns the asset ID (the hash of the bytes).
    /// It is no undo step. The file is saved with the document even when nothing refers to it yet.
    /// A command that refers to the ID, for example `setContent`, is the change.
    @discardableResult
    public func addAsset(_ data: Data, fileExtension: String) -> String {
        document.assets.add(data, fileExtension: fileExtension)
    }

    private func switchSpace(to id: String) throws -> Bool {
        guard document.board.spaces.contains(where: { $0.id == id }) else { throw CommandError.unknownSpace(id) }
        guard id != activeSpaceID else { return false }
        activeSpaceID = id
        selection = []
        return true
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
        selection = inverse.selectionAfter.intersection(existing)
        didChangeDocument()
        register(inverse, name: name)
    }

    // MARK: Selection

    /// Selects the items with these IDs. IDs that are not in the active space are dropped.
    public func select(_ ids: Set<ItemID>) {
        let existing = Set(activeSpace?.items.map(\.id) ?? [])
        selection = ids.intersection(existing)
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
    }

    // MARK: Saving

    /// Where the document stands against the last save.
    public var saveState: SaveState {
        if lastSaveError != nil { return .failed }
        return hasUnsavedChanges ? .modified : .saved
    }

    /// A save of the state at `revision` finished. Later changes keep the document marked as changed.
    /// For saves that the store does not run itself (the system saves the window's document).
    public func markSaved(revision savedRevision: Int) {
        lastSaveError = nil
        if revision == savedRevision { hasUnsavedChanges = false }
    }

    /// A save failed. The error stays visible until a later save works.
    public func markSaveFailed(_ error: any Error) {
        lastSaveError = error
    }

    private func didChangeDocument() {
        revision += 1
        hasUnsavedChanges = true
        scheduleSave()
    }

    private func scheduleSave() {
        guard let autosave else { return }
        scheduledSave?.cancel()
        scheduledSave = Task { [weak self] in
            do { try await autosave.sleep(autosave.delay) } catch { return }
            guard !Task.isCancelled else { return }
            try? await self?.saveNow()
        }
    }

    /// Saves the document now and drops a save that was waiting for the quiet time. Throws the error of the writer.
    /// Saves run one after the other. Without an `Autosave` it does nothing.
    public func saveNow() async throws {
        guard let autosave else { return }
        scheduledSave?.cancel()
        scheduledSave = nil
        let previous = runningSave
        let snapshot = document
        let savedRevision = revision
        let task = Task<Void, any Error> {
            _ = await previous?.result
            try await autosave.save(snapshot)
        }
        runningSave = task
        do {
            try await task.value
            markSaved(revision: savedRevision)
        } catch {
            markSaveFailed(error)
            throw error
        }
    }
}
