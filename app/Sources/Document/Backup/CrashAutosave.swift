import Foundation

/// A crash copy that was left behind by an app run that did not end cleanly.
public struct CrashOffer: Equatable, Sendable {
    public let documentID: UUID
    /// The crash copy, a package in the autosave folder.
    public let url: URL
    /// When the document was opened in the run that did not end cleanly.
    public let openedAt: Date?
}

/// Crash copy of each open document, in the autosave folder of the app folder.
///
/// Per document there are at most two files: `<document ID>.alfacolor`, the one crash copy, overwritten on
/// every write, and `<document ID>.open`, a marker that the document is open. A marker that is still there at
/// the next start means the run ended without closing the document. Then the crash copy is offered.
/// The folder is given by the caller and must exist; it is never created here.
public struct CrashAutosave {
    public let folder: URL
    public let clock: any BackupClock

    public init(folder: URL, clock: any BackupClock = SystemBackupClock()) {
        self.folder = folder
        self.clock = clock
    }

    public func copyURL(for documentID: UUID) -> URL {
        folder.appending(path: "\(documentID.uuidString).\(DocumentPackage.fileExtension)", directoryHint: .isDirectory)
    }

    func markerURL(for documentID: UUID) -> URL {
        folder.appending(path: "\(documentID.uuidString).open")
    }

    /// Writes the crash copy of the document. It replaces the previous copy of the same document.
    public func write(_ document: ALFAcolorDocument, appVersion: String) throws {
        try requireFolder()
        try DocumentPackage.write(document, to: copyURL(for: document.board.documentID), appVersion: appVersion)
    }

    /// Marks the document as open in this run. The marker keeps the time it was opened.
    public func markOpen(_ documentID: UUID) throws {
        try requireFolder()
        guard let text = ISODate.string(from: clock.now()) else { throw BackupError.clockOutOfRange }
        try Data(text.utf8).write(to: markerURL(for: documentID), options: .atomic)
    }

    /// A clean save: the crash copy is out of date and removed. The document stays marked as open.
    public func markSaved(_ documentID: UUID) throws {
        try removeIfPresent(copyURL(for: documentID))
    }

    /// A clean close: crash copy and marker are removed.
    public func markClosed(_ documentID: UUID) throws {
        try removeIfPresent(copyURL(for: documentID))
        try removeIfPresent(markerURL(for: documentID))
    }

    /// Crash copies left by a run that did not end cleanly. A marker without a crash copy is removed.
    public func offersAfterStart() throws -> [CrashOffer] {
        guard isDirectory(folder) else { throw BackupError.rootMissing }
        let items = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        var offers: [CrashOffer] = []
        for marker in items where marker.pathExtension == "open" {
            guard let id = UUID(uuidString: marker.deletingPathExtension().lastPathComponent) else { continue }
            let copy = copyURL(for: id)
            guard FileManager.default.fileExists(atPath: copy.path) else {
                try removeIfPresent(marker)
                continue
            }
            let text = (try? String(contentsOf: marker, encoding: .utf8)) ?? ""
            offers.append(CrashOffer(documentID: id, url: copy, openedAt: ISODate.date(from: text)))
        }
        return offers.sorted { $0.documentID.uuidString < $1.documentID.uuidString }
    }

    /// Writes the crash copy to a new place (the user chooses it). An existing item there is never replaced.
    /// On success the offer is gone: copy and marker are removed.
    public func restore(_ documentID: UUID, to target: URL) throws {
        guard !FileManager.default.fileExists(atPath: target.path) else { throw BackupError.targetExists }
        try FileManager.default.copyItem(at: copyURL(for: documentID), to: target)
        try markClosed(documentID)
    }

    /// Drops the offer: crash copy and marker are removed.
    public func discard(_ documentID: UUID) throws {
        try markClosed(documentID)
    }

    private func requireFolder() throws {
        guard isDirectory(folder) else { throw BackupError.rootMissing }
    }

    private func removeIfPresent(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isFolder: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isFolder) && isFolder.boolValue
    }
}
