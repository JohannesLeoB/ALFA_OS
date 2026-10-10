import Foundation
import Document

/// One open document: its store, the way in from a package and the way back out.
/// The window's document type is a thin shell around it, so everything here is testable without a UI.
///
/// The system saves the document. The store runs no save of its own. The system asks for a `Snapshot`
/// on the main actor, builds the package from it on a background thread, and reports the result.
@MainActor
public final class DocumentSession {
    /// The state of the document at one moment. It is a value and can leave the main actor.
    public struct Snapshot: Sendable {
        public let document: ALFAcolorDocument
        /// `BoardStore.revision` at the moment of the snapshot.
        public let revision: Int
        /// The view of each space and the active space. The package keeps them, the document does not change for them.
        public let views: [String: SpaceView]
        public let activeSpaceID: String?
        /// The undo steps at the moment of the snapshot. The package keeps them.
        public let history: UndoJournal<Edit>

        public init(document: ALFAcolorDocument, revision: Int, views: [String: SpaceView] = [:], activeSpaceID: String? = nil,
                    history: UndoJournal<Edit> = UndoJournal()) {
            self.document = document
            self.revision = revision
            self.views = views
            self.activeSpaceID = activeSpaceID
            self.history = history
        }
    }

    /// Tells one session from another. The window takes its identity from it, so a new session is a new window state.
    public let id = UUID()
    public let store: BoardStore
    /// What reading noticed (missing images, warnings). nil for a new document.
    public let readReport: ReadReport?
    /// Receives the snapshot after every change of the document or the view. Nil in tests.
    private let box: SnapshotBox?
    /// The undo steps that the package held when it was opened. They wait for the window's undo manager.
    private var savedHistory: UndoJournal<Edit>?
    /// The package folder of the file, once the document is saved. The journal is written into it after each change.
    private var packageURL: URL?
    private let journalWriter = JournalWriter()

    /// A new, empty document. It has never been saved.
    public convenience init() {
        self.init(document: ALFAcolorDocument(), report: nil, isSaved: false)
    }

    /// Opens a package. Throws `PackageError` (with a message from the catalog) when it cannot be read.
    public convenience init(wrapper: FileWrapper) throws {
        let result = try DocumentPackage.read(from: wrapper)
        self.init(document: result.document, report: result.report)
    }

    /// With `box`, every change lands in the box, so the system can read the last state off the main actor.
    /// `isSaved` is false for a document that is not in a file yet.
    public init(document: ALFAcolorDocument, report: ReadReport?, box: SnapshotBox? = nil, isSaved: Bool = true) {
        // Values beyond the number limits are cut here, and each cut item is named in the read report.
        let limits = ReadLimits.limited(document)
        store = BoardStore(document: limits.document, isSaved: isSaved)
        var merged = report ?? ReadReport()
        merged.warnings += limits.warnings
        readReport = limits.warnings.isEmpty ? report : merged
        self.box = box
        let saved = UndoJournal<Edit>.load(from: limits.document)
        if saved.problem == nil, !saved.journal.steps.isEmpty { savedHistory = saved.journal }
        box?.store(snapshot())
        store.onChange = { [weak self] _, _ in self?.publishChange() }
        store.onViewChange = { [weak self] in self?.publish() }
    }

    public func snapshot() -> Snapshot {
        Snapshot(document: store.document, revision: store.revision,
                 views: store.viewports.mapValues { SpaceView(zoom: $0.zoom, offsetX: $0.offsetX, offsetY: $0.offsetY) },
                 activeSpaceID: store.activeSpaceID, history: store.exportHistory())
    }

    /// Puts the undo steps of the opened package back on the undo stack of the store, once.
    /// Call it after the window has given its undo manager to the store. Returns false when the package held no steps,
    /// or when they do not fit the board: then the steps are dropped and the document opens without undo history.
    @discardableResult
    public func restoreSavedHistory() -> Bool {
        guard let journal = savedHistory else { return false }
        savedHistory = nil
        guard store.restoreHistory(journal) else { return false }
        publish()
        return true
    }

    private func publish() {
        box?.store(snapshot())
    }

    /// Publishes the state and, for a document that is in a file, writes its undo journal into the package.
    private func publishChange() {
        let state = snapshot()
        box?.store(state)
        if let packageURL { journalWriter.submit(state, to: packageURL) }
    }

    /// Tells the session where the package is (nil for a document that is not saved). From then on every change
    /// of the document writes the undo journal into the package in the background. Nothing is written by this call.
    public func attachPackage(_ url: URL?) {
        packageURL = url
    }

    /// Waits until the journal of the last change is on disk. Call it when the window closes and when the app quits.
    public func flushJournal() {
        journalWriter.flush()
    }

    /// Builds the package. With `existing` (the file as it is on disk), images that are in it already are taken over.
    /// Only images that an item uses are saved; the document keeps the others in memory, so an undo still finds them.
    /// Needs no actor: it runs where the system calls it.
    public nonisolated static func fileWrapper(for snapshot: Snapshot, appVersion: String, existing: FileWrapper?) throws -> FileWrapper {
        var document = snapshot.document
        document.spaceViews = snapshot.views
        document.activeSpaceID = snapshot.activeSpaceID
        let used = Set(document.board.spaces.flatMap(\.items).compactMap { item -> String? in
            if case .image(let id, _, _) = item.content { id } else { nil }
        })
        for id in document.assets.ids where !used.contains(id) { document.assets.remove(id) }
        var history = snapshot.history
        history.digest = document.boardDigest
        try history.store(in: &document)
        return try DocumentPackage.fileWrapper(for: document, appVersion: appVersion, existing: existing)
    }

    /// The package of this snapshot was built and handed to the system.
    public func didSave(_ snapshot: Snapshot) {
        store.markSaved(snapshot.document)
    }

    public func didFailSaving(_ error: any Error) {
        store.markSaveFailed(error)
    }
}

/// The last snapshot of a document, readable from any thread. The session writes it on every change.
/// The system saves on a background queue while the main thread waits, so a save must not jump to the main actor.
public final class SnapshotBox: @unchecked Sendable {
    private let lock = NSLock()
    private var latest: DocumentSession.Snapshot

    public init(_ initial: DocumentSession.Snapshot) {
        latest = initial
    }

    public func store(_ snapshot: DocumentSession.Snapshot) {
        lock.withLock { latest = snapshot }
    }

    public func read() -> DocumentSession.Snapshot {
        lock.withLock { latest }
    }
}

/// Writes the undo journal of the newest snapshot into the package, on a background queue.
/// A change that comes while a write is waiting replaces the waiting snapshot, so only the newest one is written.
/// A failed write is dropped: the next change writes the whole journal again, and a save carries it as well.
final class JournalWriter: @unchecked Sendable {
    private let queue = DispatchQueue(label: "alfacolor.undo-journal", qos: .utility)
    private let lock = NSLock()
    private var waiting: (snapshot: DocumentSession.Snapshot, package: URL)?

    func submit(_ snapshot: DocumentSession.Snapshot, to package: URL) {
        let needsRun = lock.withLock { () -> Bool in
            let idle = waiting == nil
            waiting = (snapshot, package)
            return idle
        }
        if needsRun { queue.async { self.writeWaiting() } }
    }

    /// Returns when everything submitted before the call is on disk.
    func flush() {
        queue.sync { writeWaiting() }
    }

    private func writeWaiting() {
        let job = lock.withLock { () -> (snapshot: DocumentSession.Snapshot, package: URL)? in
            defer { waiting = nil }
            return waiting
        }
        guard let job else { return }
        var journal = job.snapshot.history
        journal.digest = job.snapshot.document.boardDigest
        try? journal.write(toPackage: job.package)
    }
}
