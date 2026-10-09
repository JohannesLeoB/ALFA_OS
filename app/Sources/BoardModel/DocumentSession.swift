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

        public init(document: ALFAcolorDocument, revision: Int, views: [String: SpaceView] = [:], activeSpaceID: String? = nil) {
            self.document = document
            self.revision = revision
            self.views = views
            self.activeSpaceID = activeSpaceID
        }
    }

    /// Tells one session from another. The window takes its identity from it, so a new session is a new window state.
    public let id = UUID()
    public let store: BoardStore
    /// What reading noticed (missing images, warnings). nil for a new document.
    public let readReport: ReadReport?
    /// Receives the snapshot after every change of the document or the view. Nil in tests.
    private let box: SnapshotBox?

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
        box?.store(snapshot())
        store.onChange = { [weak self] _, _ in self?.publish() }
        store.onViewChange = { [weak self] in self?.publish() }
    }

    public func snapshot() -> Snapshot {
        Snapshot(document: store.document, revision: store.revision,
                 views: store.viewports.mapValues { SpaceView(zoom: $0.zoom, offsetX: $0.offsetX, offsetY: $0.offsetY) },
                 activeSpaceID: store.activeSpaceID)
    }

    private func publish() {
        box?.store(snapshot())
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
