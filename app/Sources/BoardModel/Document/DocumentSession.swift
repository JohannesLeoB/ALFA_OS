import Foundation
import Document

/// One open document: its store, the way in from a package and the way back out.
/// The window's document type is a thin shell around it, so everything here is testable without a UI.
///
/// The system saves the document (also by itself, at intervals). So the store has no `Autosave` here,
/// and the file is written once per save. The system asks for a `Snapshot` on the main actor,
/// builds the package from it on a background thread, and reports the result.
@MainActor
public final class DocumentSession {
    /// The state of the document at one moment. It is a value and can leave the main actor.
    public struct Snapshot: Sendable {
        public let document: ALFAcolorDocument
        /// `BoardStore.revision` at the moment of the snapshot.
        public let revision: Int
    }

    public let store: BoardStore
    /// What reading noticed (missing images, warnings). nil for a new document.
    public let readReport: ReadReport?

    /// A new, empty document.
    public convenience init() {
        self.init(document: ALFAcolorDocument(), report: nil)
    }

    /// Opens a package. Throws `PackageError` (with a message from the catalog) when it cannot be read.
    public convenience init(wrapper: FileWrapper) throws {
        let result = try DocumentPackage.read(from: wrapper)
        self.init(document: result.document, report: result.report)
    }

    public init(document: ALFAcolorDocument, report: ReadReport?) {
        store = BoardStore(document: document)
        readReport = report
    }

    public func snapshot() -> Snapshot {
        Snapshot(document: store.document, revision: store.revision)
    }

    /// Builds the package. With `existing` (the file as it is on disk), images that are in it already are taken over.
    /// Needs no actor: it runs where the system calls it.
    public nonisolated static func fileWrapper(for snapshot: Snapshot, appVersion: String, existing: FileWrapper?) throws -> FileWrapper {
        try DocumentPackage.fileWrapper(for: snapshot.document, appVersion: appVersion, existing: existing)
    }

    /// The package of this snapshot was built and handed to the system.
    public func didSave(_ snapshot: Snapshot) {
        store.markSaved(revision: snapshot.revision)
    }

    public func didFailSaving(_ error: any Error) {
        store.markSaveFailed(error)
    }
}
