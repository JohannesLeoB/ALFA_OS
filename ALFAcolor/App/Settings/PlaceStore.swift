import AppKit
import Foundation
import Observation
import ALFAcolorCore

/// The places of the app. The list is kept in a file next to the app's other files, and each place opens
/// through its security-scoped bookmark. One instance for the whole app; each change is written at once.
@MainActor
@Observable
final class PlaceStore {
    static let shared = PlaceStore()

    /// Where the list is kept, in the Application Support folder of the app.
    static var defaultFileURL: URL {
        let support = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                    appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        return support.appending(path: "ALFAcolor", directoryHint: .isDirectory).appending(path: "place-register.json")
    }

    private(set) var registry: PlaceRegistry
    /// True when the file exists but cannot be read. Nothing is written then, so the file is not overwritten.
    private(set) var fileIsUnreadable = false
    private let fileURL: URL

    init(fileURL: URL = PlaceStore.defaultFileURL) {
        self.fileURL = fileURL
        switch PlaceFile.load(from: fileURL) {
        case .missing:
            registry = PlaceRegistry()
        case .readable(let read):
            registry = read
        case .unreadable:
            registry = PlaceRegistry()
            fileIsUnreadable = true
        }
    }

    /// Sets the unreadable file aside, next to itself, and starts with an empty list. Nothing is overwritten.
    func setUnreadableFileAside() throws {
        try PlaceFile.setAside(fileURL, date: .now)
        registry = PlaceRegistry()
        fileIsUnreadable = false
    }

    /// The file that keeps the places, for showing it in the Finder.
    var registerFileURL: URL { fileURL }

    var places: [Place] { registry.places }

    /// The app folder, nil until the user chooses one.
    var appFolder: Place? {
        guard let id = registry.appFolderID else { return nil }
        return registry.place(id)
    }

    /// The access of a place now: reachable at a folder, outdated, or unreachable.
    func access(to place: Place) -> PlaceAccess {
        PlaceAccess.check(place)
    }

    /// Runs the work with the folder of a reachable place open. The security scope is held only while the work runs.
    func withFolder<Output>(of place: Place, _ work: (URL) throws -> Output) throws -> Output {
        guard case .reachable(let url) = access(to: place) else { throw PlaceStoreError.notReachable }
        let scoped = place.bookmark != nil && url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        return try work(url)
    }

    /// Adds a folder the user chose. The kind is detected; the user may change it later.
    @discardableResult
    func addFolder(_ folder: URL, roles: Set<PlaceRole>) throws -> Place {
        let bookmark = try PlaceBookmarks.make(for: folder)
        let kind = PlaceKind.detect(path: folder.path, home: Self.homePath, containsGitEntry: Self.hasGitEntry(folder))
        let place = try registry.add(name: folder.lastPathComponent, kind: kind, roles: roles,
                                     path: folder.path, bookmark: bookmark, at: .now)
        try save()
        return place
    }

    /// Makes the app folder inside the Application Support folder of the app, the default proposal.
    func useDefaultAppFolder() throws {
        let folder = Self.defaultFileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let place = try registry.add(name: folder.lastPathComponent, kind: .folder, roles: [.storage, .sourceLibrary],
                                     path: folder.path, bookmark: nil, at: .now)
        try registry.chooseAppFolder(place.id)
        try AppFolder.create(in: folder)
        try save()
    }

    /// Makes a folder the user chose the app folder. Its subfolders are created inside it.
    func useAppFolder(_ folder: URL) throws {
        try AppFolder.create(in: folder)
        let place = try addFolder(folder, roles: [.storage, .sourceLibrary])
        try registry.chooseAppFolder(place.id)
        try save()
    }

    /// Gives a place a new folder after the user chose it again. The id and the roles stay.
    func relocate(_ place: Place, to folder: URL) throws {
        let bookmark = try PlaceBookmarks.make(for: folder)
        try registry.relocate(place.id, path: folder.path, bookmark: bookmark)
        try save()
    }

    func setRoles(_ roles: Set<PlaceRole>, for place: Place) throws {
        try registry.setRoles(roles, for: place.id)
        try save()
    }

    func rename(_ place: Place, to name: String) throws {
        try registry.rename(place.id, to: name)
        try save()
    }

    /// Moves places in the list, as a list drop reports it. The file is written at once.
    func reorder(from source: IndexSet, to destination: Int) throws {
        registry.reorder(from: source, to: destination)
        try save()
    }

    func setKind(_ kind: PlaceKind, for place: Place) throws {
        try registry.setKind(kind, for: place.id)
        try save()
    }

    func remove(_ place: Place) throws {
        try registry.remove(place.id)
        try save()
    }

    private func save() throws {
        guard !fileIsUnreadable else { throw PlaceStoreError.fileUnreadable }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(registry).write(to: fileURL, options: .atomic)
    }

    private static var homePath: String {
        NSHomeDirectoryForUser(NSUserName()) ?? NSHomeDirectory()
    }

    private static func hasGitEntry(_ folder: URL) -> Bool {
        FileManager.default.fileExists(atPath: folder.appending(path: ".git").path)
    }
}

/// The reasons why a place cannot be used right now.
enum PlaceStoreError: Error {
    case notReachable
    case fileUnreadable
}
