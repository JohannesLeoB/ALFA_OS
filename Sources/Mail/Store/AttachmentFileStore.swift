import Foundation
import GRDB
import Hub
import Storage

public enum AttachmentFolder {
    public static let name = "mail-attachments"

    public static func bookmark(for url: URL) -> Data? {
        try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    public static func url(for bookmark: Data) -> URL? {
        var stale = false
        return try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale)
    }

    static func access(_ bookmark: Data) -> FolderAccess? {
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale),
              url.startAccessingSecurityScopedResource() else { return nil }
        return FolderAccess(url: url, renewed: stale ? Self.bookmark(for: url) : nil) { url.stopAccessingSecurityScopedResource() }
    }
}

struct FolderAccess: Sendable {
    let url: URL
    let renewed: Data?
    let stop: @Sendable () -> Void
}

public enum AttachmentSourceStore {
    public static func data(at url: URL) async -> Data? {
        await Task.detached { try? Data(contentsOf: url) }.value
    }
}

@MainActor
final class AttachmentFileStore {
    private let database: SQLiteStore
    private let directory: URL
    private let now: @Sendable () -> Date
    let settings: @MainActor () -> MailStoreSettings
    private let cap: @MainActor (MailStoreSettings) -> Int?
    private let resolve: @MainActor (Data) -> FolderAccess?
    private let renew: @MainActor (Data) -> Void
    private var scopes: [Data: FolderAccess] = [:]
    private var moving = false

    init(database: SQLiteStore, directory: URL, now: @escaping @Sendable () -> Date = { Date() },
         settings: @escaping @MainActor () -> MailStoreSettings = { MailStoreSettings() },
         cap: @escaping @MainActor (MailStoreSettings) -> Int? = { $0.limit.bytes },
         resolve: @escaping @MainActor (Data) -> FolderAccess? = { AttachmentFolder.access($0) },
         renew: @escaping @MainActor (Data) -> Void = { _ in }) {
        self.database = database
        self.directory = directory
        self.now = now
        self.settings = settings
        self.cap = cap
        self.resolve = resolve
        self.renew = renew
    }

    isolated deinit {
        for access in scopes.values { access.stop() }
    }

    var enabled: Bool { settings().attachments && !moving }

    var limit: Int? { cap(settings()) }

    func root() -> URL? {
        if !moving { release() }
        return root(for: settings().folder)
    }

    func root(for bookmark: Data?) -> URL? {
        guard let bookmark else { return directory.appendingPathComponent(AttachmentFolder.name, isDirectory: true) }
        if let known = scopes[bookmark] { return known.url.appendingPathComponent(AttachmentFolder.name, isDirectory: true) }
        guard let access = resolve(bookmark) else { return nil }
        if let renewed = access.renewed, settings().folder == bookmark { renew(renewed) }
        if let renewed = access.renewed, settings().folder == renewed {
            scopes[renewed] = access
        } else {
            scopes[bookmark] = access
        }
        return access.url.appendingPathComponent(AttachmentFolder.name, isDirectory: true)
    }

    private func release() {
        let current = settings().folder
        for (bookmark, access) in scopes where bookmark != current {
            access.stop()
            scopes[bookmark] = nil
        }
    }

    func files(inlet: String? = nil) -> [StoredAttachment] {
        let rows = try? database.read { db in
            let all = inlet == nil
            return try Row.fetchAll(db, sql: "SELECT * FROM mail_attachment_file" + (all ? "" : " WHERE inlet = ?"),
                                    arguments: all ? [] : [inlet ?? ""]).map(Self.record)
        }
        return rows ?? []
    }

    func stored(_ inlet: String, message: String) -> Set<String> {
        let ids = try? database.read { db in
            try String.fetchAll(db, sql: "SELECT attachment FROM mail_attachment_file WHERE inlet = ? AND message = ?",
                                arguments: [inlet, message])
        }
        return Set(ids ?? [])
    }

    func admits(size: Int, receivedAt: Date?) -> Bool {
        guard enabled else { return false }
        let probe = StoredAttachment(inlet: "", message: "", attachment: "", path: "", size: size, receivedAt: receivedAt, storedAt: now())
        return AttachmentFileEngine.admits(probe, among: files(), limit: limit)
    }

    func data(_ inlet: String, message: String, attachment: String) async -> Data? {
        guard let entry = file(inlet, message, attachment), let folder = root() else { return nil }
        let url = folder.appendingPathComponent(entry.path)
        let found = await AttachmentSourceStore.data(at: url)
        if let found, found.count == entry.size { return found }
        if !moving { remove([entry]) }
        return nil
    }

    @discardableResult
    func store(_ data: Data, inlet: String, message: String, attachment: String, filename: String, receivedAt: Date?) async -> Bool {
        guard enabled, let folder = root() else { return false }
        let path = AttachmentFileEngine.relativePath(inlet: inlet, message: message, attachment: attachment, filename: filename)
        let entry = StoredAttachment(inlet: inlet, message: message, attachment: attachment, path: path, size: data.count,
                                     receivedAt: receivedAt, storedAt: now())
        guard AttachmentFileEngine.admits(entry, among: files(), limit: limit) else { return false }
        let url = folder.appendingPathComponent(path)
        guard await Self.write(data, to: url) else { return false }
        guard enabled else {
            try? FileManager.default.removeItem(at: url)
            Self.prune(url.deletingLastPathComponent(), below: folder)
            return false
        }
        let previous = file(inlet, message, attachment)
        let saved: Void? = try? database.write { db in
            try db.execute(sql: """
                INSERT OR REPLACE INTO mail_attachment_file (inlet, message, attachment, path, size, receivedAt, storedAt)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [entry.inlet, entry.message, entry.attachment, entry.path, entry.size,
                            entry.receivedAt?.timeIntervalSince1970, entry.storedAt.timeIntervalSince1970])
        }
        guard saved != nil else {
            try? FileManager.default.removeItem(at: url)
            return false
        }
        if let previous, previous.path != path {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(previous.path))
            Self.prune(folder.appendingPathComponent(previous.path).deletingLastPathComponent(), below: folder)
        }
        enforce()
        return true
    }

    func enforce() {
        remove(AttachmentFileEngine.evictions(files(), limit: limit))
    }

    func sweep(_ inlet: String) {
        let rows = try? database.read { db in
            try Row.fetchAll(db, sql: """
                SELECT * FROM mail_attachment_file WHERE inlet = ?1 AND NOT EXISTS
                (SELECT 1 FROM mail_message WHERE mail_message.inlet = mail_attachment_file.inlet
                 AND mail_message.id = mail_attachment_file.message)
                """, arguments: [inlet]).map(Self.record)
        }
        remove(rows ?? [])
    }

    func removeInlet(_ inlet: String) {
        remove(files(inlet: inlet), force: true)
        guard let directory = root() else { return }
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(AttachmentFileEngine.inletDirectory(inlet), isDirectory: true))
    }

    func removeAll() {
        remove(files(), force: true)
        guard let directory = root() else { return }
        try? FileManager.default.removeItem(at: directory)
    }

    func move(to bookmark: Data?, commit: @MainActor () -> Void) async -> Bool {
        moving = true
        defer {
            moving = false
            release()
        }
        guard let target = root(for: bookmark) else { return false }
        guard let source = root(for: settings().folder) else { return files().isEmpty ? finish(commit) : false }
        guard source.standardizedFileURL != target.standardizedFileURL else { return finish(commit) }
        let paths = files().map(\.path)
        let moved = await Task.detached { Self.relocate(paths, from: source, to: target) }.value
        guard moved else { return false }
        try? FileManager.default.removeItem(at: source)
        commit()
        return true
    }

    private func finish(_ commit: @MainActor () -> Void) -> Bool {
        commit()
        return true
    }

    private func file(_ inlet: String, _ message: String, _ attachment: String) -> StoredAttachment? {
        let found = try? database.read { db in
            try Row.fetchOne(db, sql: "SELECT * FROM mail_attachment_file WHERE inlet = ? AND message = ? AND attachment = ?",
                             arguments: [inlet, message, attachment]).map(Self.record)
        }
        return found.flatMap { $0 }
    }

    private func remove(_ list: [StoredAttachment], force: Bool = false) {
        guard !list.isEmpty else { return }
        let directory = root()
        guard directory != nil || force else { return }
        if let directory {
            for entry in list {
                let url = directory.appendingPathComponent(entry.path)
                try? FileManager.default.removeItem(at: url)
                Self.prune(url.deletingLastPathComponent(), below: directory)
            }
        }
        try? database.write { db in
            for entry in list {
                try db.execute(sql: "DELETE FROM mail_attachment_file WHERE inlet = ? AND message = ? AND attachment = ?",
                               arguments: [entry.inlet, entry.message, entry.attachment])
            }
        }
    }

    nonisolated private static func record(_ row: Row) -> StoredAttachment {
        let received: Double? = row["receivedAt"]
        let stored: Double = row["storedAt"]
        return StoredAttachment(inlet: row["inlet"], message: row["message"], attachment: row["attachment"], path: row["path"],
                                size: row["size"], receivedAt: received.map { Date(timeIntervalSince1970: $0) },
                                storedAt: Date(timeIntervalSince1970: stored))
    }

    nonisolated private static func write(_ data: Data, to url: URL) async -> Bool {
        await Task.detached {
            do {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: url, options: .atomic)
                return true
            } catch {
                return false
            }
        }.value
    }

    nonisolated private static func relocate(_ paths: [String], from source: URL, to target: URL) -> Bool {
        let manager = FileManager.default
        var copied: [URL] = []
        for path in paths {
            let from = source.appendingPathComponent(path)
            let to = target.appendingPathComponent(path)
            guard manager.fileExists(atPath: from.path) else { continue }
            do {
                try manager.createDirectory(at: to.deletingLastPathComponent(), withIntermediateDirectories: true)
                if manager.fileExists(atPath: to.path) { try manager.removeItem(at: to) }
                try manager.copyItem(at: from, to: to)
                copied.append(to)
            } catch {
                for url in copied { try? manager.removeItem(at: url) }
                return false
            }
        }
        return true
    }

    nonisolated private static func prune(_ directory: URL, below root: URL) {
        let manager = FileManager.default
        var current = directory.standardizedFileURL
        let stop = root.standardizedFileURL
        while current.path.hasPrefix(stop.path), current != stop {
            guard (try? manager.contentsOfDirectory(atPath: current.path))?.isEmpty == true else { return }
            try? manager.removeItem(at: current)
            current = current.deletingLastPathComponent()
        }
    }
}
