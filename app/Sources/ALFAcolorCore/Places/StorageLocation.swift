import Foundation

/// Decides where an app file lives. When the app folder is reachable, the file belongs in its subfolder; a file
/// still at its old place is moved there. Nothing is deleted or overwritten by `resolve`. Without a reachable
/// app folder, everything stays at the old place, and no folder is created in an unreachable place.
public enum StorageLocation {
    /// The address to use for a file now.
    /// - Parameters:
    ///   - oldURL: where the file lay before the app folder was chosen.
    ///   - appFolder: the chosen app folder, nil when none is chosen.
    ///   - subfolder: the subfolder of the app folder for this kind of file.
    /// A file of the same name in the app folder is never overwritten: the old file then stays where it is.
    /// Use `conflict` to find that case and `settle` to let the user decide.
    public static func resolve(oldURL: URL, appFolder: URL?, subfolder: AppFolder.Subfolder,
                               fileManager: FileManager = .default) throws -> URL {
        guard let appFolder else { return oldURL }
        let state = AppFolder.state(of: appFolder, fileManager: fileManager)
        if state == .unreachable { return oldURL }
        if state == .needsSubfolders { try AppFolder.create(in: appFolder, fileManager: fileManager) }

        let target = target(for: oldURL, appFolder: appFolder, subfolder: subfolder)
        guard fileManager.fileExists(atPath: oldURL.path) else { return target }
        if fileManager.fileExists(atPath: target.path) { return oldURL }
        try fileManager.moveItem(at: oldURL, to: target)
        return target
    }

    /// The conflict of a file at its old place and a file of the same name in the app folder, nil when there is none.
    /// Nothing is changed. An unreachable app folder gives no conflict, since nothing would move there.
    public static func conflict(oldURL: URL, appFolder: URL?, subfolder: AppFolder.Subfolder,
                                fileManager: FileManager = .default) -> StorageConflict? {
        guard let appFolder, AppFolder.state(of: appFolder, fileManager: fileManager) != .unreachable else { return nil }
        let target = target(for: oldURL, appFolder: appFolder, subfolder: subfolder)
        guard fileManager.fileExists(atPath: oldURL.path), fileManager.fileExists(atPath: target.path) else { return nil }
        return StorageConflict(oldURL: oldURL, targetURL: target)
    }

    /// Carries out the choice of the user and returns the address the file lives at now.
    /// - Parameters:
    ///   - date: the time for the name of a set-aside file.
    public static func settle(_ conflict: StorageConflict, with choice: StorageChoice, date: Date = .now,
                              fileManager: FileManager = .default) throws -> URL {
        let target = conflict.targetURL
        switch choice {
        case .keepTarget:
            return target
        case .replace, .setAside:
            try fileManager.moveItem(at: target, to: asideURL(for: target, date: date, fileManager: fileManager))
            try fileManager.moveItem(at: conflict.oldURL, to: target)
            return target
        case .rename(let name):
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed != ".", trimmed != "..", !trimmed.contains("/") else {
                throw StorageConflictError.invalidName
            }
            let renamed = target.deletingLastPathComponent().appending(path: trimmed)
            guard !fileManager.fileExists(atPath: renamed.path) else { throw StorageConflictError.nameTaken }
            try fileManager.moveItem(at: conflict.oldURL, to: renamed)
            return renamed
        }
    }

    private static func target(for oldURL: URL, appFolder: URL, subfolder: AppFolder.Subfolder) -> URL {
        appFolder
            .appending(path: subfolder.folderName, directoryHint: .isDirectory)
            .appending(path: oldURL.lastPathComponent)
    }

    /// A name next to the file that is not taken yet: the stem, the time stamp, and the extension.
    private static func asideURL(for target: URL, date: Date, fileManager: FileManager) -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let stamp = formatter.string(from: date)
        let stem = target.deletingPathExtension().lastPathComponent
        let ext = target.pathExtension
        var counter = 0
        while true {
            let suffix = counter == 0 ? "" : "-\(counter)"
            let base = "\(stem)-\(stamp)\(suffix)"
            let name = ext.isEmpty ? base : "\(base).\(ext)"
            let url = target.deletingLastPathComponent().appending(path: name)
            if !fileManager.fileExists(atPath: url.path) { return url }
            counter += 1
        }
    }
}

/// A file at its old place and a file of the same name in the app folder. The user decides what happens.
public struct StorageConflict: Equatable, Sendable {
    /// The file at its old place.
    public let oldURL: URL
    /// The file of the same name in the app folder.
    public let targetURL: URL

    public init(oldURL: URL, targetURL: URL) {
        self.oldURL = oldURL
        self.targetURL = targetURL
    }
}

/// What the user chooses when a file meets a file of the same name in the app folder.
public enum StorageChoice: Equatable, Sendable {
    /// The file in the app folder stays and is used. The old file does not move and stays where it is.
    case keepTarget
    /// The file in the app folder is set aside under a time stamp name first, then the old file moves in under its own name.
    case replace
    /// The file in the app folder gets a time stamp name. The old file moves in under its own name.
    case setAside
    /// The old file moves in under this name. The file in the app folder stays.
    case rename(String)
}

/// The reasons why a chosen name cannot be used for a file.
public enum StorageConflictError: Error, Equatable, Sendable {
    /// A file of that name already exists in the app folder.
    case nameTaken
    /// The name is empty, is a dot name, or holds a path separator.
    case invalidName
}
