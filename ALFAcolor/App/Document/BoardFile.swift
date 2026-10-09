import SwiftUI
import UniformTypeIdentifiers
import BoardModel
import Document

/// The document type of the app: one window per `.alfacolor` package, each with its own store.
/// The system opens, saves (also by itself), keeps the recent list and shows errors from reading and writing.
/// The work is in `DocumentSession`; this class only answers the calls of the system.
///
/// Reading and creating work on any thread: they only hold the parsed value. The session with its store
/// is made on first use on the main actor, when the window asks for it. Its last state is kept in a box
/// that any thread can read, because the system takes the snapshot for a save on a background queue.
final class BoardFile: @preconcurrency ReferenceFileDocument, @unchecked Sendable {
    static var readableContentTypes: [UTType] { [.alfacolor] }

    private let opened: ALFAcolorDocument
    private let report: ReadReport?
    private let latest: SnapshotBox

    @MainActor private(set) lazy var session = DocumentSession(document: opened, report: report, box: latest)

    init() {
        opened = ALFAcolorDocument()
        report = nil
        latest = SnapshotBox(DocumentSession.Snapshot(document: opened, revision: 0))
    }

    required init(configuration: ReadConfiguration) throws {
        let result = try DocumentPackage.read(from: configuration.file)
        opened = result.document
        report = result.report
        latest = SnapshotBox(DocumentSession.Snapshot(document: opened, revision: 0))
    }

    /// Runs off the main actor. It reads the last state the session published and never touches the session.
    func snapshot(contentType: UTType) throws -> DocumentSession.Snapshot {
        latest.read()
    }

    /// The system calls this off the main thread. The result goes back to the store on the main actor.
    func fileWrapper(snapshot: DocumentSession.Snapshot, configuration: WriteConfiguration) throws -> FileWrapper {
        do {
            let wrapper = try DocumentSession.fileWrapper(for: snapshot, appVersion: Self.appVersion, existing: configuration.existingFile)
            Task { @MainActor in session.didSave(snapshot) }
            return wrapper
        } catch {
            Task { @MainActor in session.didFailSaving(error) }
            throw error
        }
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }
}
