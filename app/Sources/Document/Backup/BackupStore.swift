import Foundation

/// The time source of the backup code. Tests set the time by hand.
public protocol BackupClock {
    func now() -> Date
}

/// The real clock.
public struct SystemBackupClock: BackupClock {
    public init() {}

    public func now() -> Date { Date() }
}

public enum BackupError: Error, Equatable, Sendable {
    /// The backup folder of the app does not exist (for example a disk that is not connected).
    case rootMissing
    /// The package to copy does not exist.
    case sourceMissing
    /// The clock gave a time that cannot be written into a file name.
    case clockOutOfRange
    /// The target of a restore already exists; nothing is overwritten.
    case targetExists
    /// Only backups of documents that are no longer known may be deleted this way.
    case documentIsKnown
}

/// A backup folder whose document is not known any more.
public struct OrphanedBackups: Equatable, Sendable {
    public let documentID: UUID
    public let url: URL
    /// Number of backups in the folder.
    public let count: Int

    public init(documentID: UUID, url: URL, count: Int) {
        self.documentID = documentID
        self.url = url
        self.count = count
    }
}

/// One backup of a document: a full copy of its package folder, named by the time it was taken.
public struct BackupRecord: Equatable, Sendable {
    public let url: URL
    public let documentID: UUID
    public let date: Date

    public init(url: URL, documentID: UUID, date: Date) {
        self.url = url
        self.documentID = documentID
        self.date = date
    }
}

/// Keeps backups of documents below one backup folder: `<root>/<document ID>/<time>.alfacolor`.
///
/// The folder `root` is given by the caller (the app folder's backup place). It is never created here,
/// so a missing disk is reported instead of writing to another place.
public struct BackupStore {
    public enum Outcome: Equatable, Sendable {
        case created(BackupRecord)
        case unchanged
    }

    public let root: URL
    public let clock: any BackupClock

    public init(root: URL, clock: any BackupClock = SystemBackupClock()) {
        self.root = root
        self.clock = clock
    }

    /// Copies the saved package into the backup folder, unless the newest backup has the same content.
    @discardableResult
    public func backupIfChanged(package: URL, documentID: UUID) throws -> Outcome {
        guard isDirectory(root) else { throw BackupError.rootMissing }
        guard isDirectory(package) else { throw BackupError.sourceMissing }

        let current = try PackageFingerprint.of(package)
        if let newest = try backups(for: documentID).first, try PackageFingerprint.of(newest.url) == current {
            return .unchanged
        }

        let folder = documentFolder(documentID)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let date = try freeDate(from: clock.now(), in: folder)
        let target = folder.appending(path: Self.fileName(for: date), directoryHint: .isDirectory)
        // Copy under a hidden name first, so a half-written copy is never listed as a backup.
        let partial = folder.appending(path: ".partial-\(UUID().uuidString)", directoryHint: .isDirectory)
        do {
            try FileManager.default.copyItem(at: package, to: partial)
            try FileManager.default.moveItem(at: partial, to: target)
        } catch {
            try? FileManager.default.removeItem(at: partial)
            throw error
        }
        try thin(documentID)
        return .created(BackupRecord(url: target, documentID: documentID, date: date))
    }

    /// Copies a backup to a new place. An existing item at `target` is never replaced.
    public func restore(_ record: BackupRecord, to target: URL) throws {
        guard !FileManager.default.fileExists(atPath: target.path) else { throw BackupError.targetExists }
        try FileManager.default.copyItem(at: record.url, to: target)
    }

    /// Document folders in the backup root whose document is not in `knownDocuments`. Nothing is deleted.
    public func orphanedBackups(knownDocuments: Set<UUID>) throws -> [OrphanedBackups] {
        guard isDirectory(root) else { throw BackupError.rootMissing }
        let items = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        return try items.compactMap { url -> OrphanedBackups? in
            guard isDirectory(url), let id = UUID(uuidString: url.lastPathComponent), !knownDocuments.contains(id) else {
                return nil
            }
            return OrphanedBackups(documentID: id, url: url, count: try backups(for: id).count)
        }.sorted { $0.url.lastPathComponent < $1.url.lastPathComponent }
    }

    /// Deletes all backups of a document that is no longer known. Only called on request, never automatically.
    public func deleteOrphanedBackups(_ documentID: UUID, knownDocuments: Set<UUID>) throws {
        guard !knownDocuments.contains(documentID) else { throw BackupError.documentIsKnown }
        let folder = documentFolder(documentID)
        guard isDirectory(folder) else { return }
        try FileManager.default.removeItem(at: folder)
    }

    /// Removes the backups that `BackupThinning` names for this document.
    private func thin(_ documentID: UUID) throws {
        let records = try backups(for: documentID)
        let entries = records.map { BackupEntry(id: $0.url.lastPathComponent, date: $0.date) }
        for name in BackupThinning.removals(entries) {
            try FileManager.default.removeItem(at: documentFolder(documentID).appending(path: name, directoryHint: .isDirectory))
        }
    }

    /// The backups of one document, newest first. Empty when there is no folder for it.
    public func backups(for documentID: UUID) throws -> [BackupRecord] {
        let folder = documentFolder(documentID)
        guard isDirectory(folder) else { return [] }
        let items = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        return items.compactMap { url -> BackupRecord? in
            guard url.pathExtension == DocumentPackage.fileExtension,
                  let date = Self.date(fromFileName: url.lastPathComponent) else { return nil }
            return BackupRecord(url: url, documentID: documentID, date: date)
        }.sorted { $0.date > $1.date }
    }

    func documentFolder(_ documentID: UUID) -> URL {
        root.appending(path: documentID.uuidString, directoryHint: .isDirectory)
    }

    /// The clock time rounded to milliseconds, moved one millisecond later while a backup with that name exists.
    private func freeDate(from now: Date, in folder: URL) throws -> Date {
        guard let text = ISODate.string(from: now), var date = ISODate.date(from: text) else {
            throw BackupError.clockOutOfRange
        }
        while FileManager.default.fileExists(atPath: folder.appending(path: Self.fileName(for: date)).path) {
            date = date.addingTimeInterval(0.001)
        }
        return date
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isFolder: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isFolder) && isFolder.boolValue
    }

    /// "2026-10-09T12:34:56.789Z" becomes "2026-10-09T123456.789Z.alfacolor": colons are not used in file names.
    static func fileName(for date: Date) -> String {
        let stamp = (ISODate.string(from: date) ?? "").replacingOccurrences(of: ":", with: "")
        return stamp + "." + DocumentPackage.fileExtension
    }

    /// The inverse of `fileName(for:)`. Nil for names that do not have the form.
    static func date(fromFileName name: String) -> Date? {
        let suffix = "." + DocumentPackage.fileExtension
        guard name.hasSuffix(suffix) else { return nil }
        let chars = Array(name.dropLast(suffix.count))
        guard chars.count == 22 else { return nil }
        let text = String(chars[0..<13]) + ":" + String(chars[13..<15]) + ":" + String(chars[15...])
        return ISODate.date(from: text)
    }
}
