import Foundation

/// Decides where an app file lives. When the app folder is reachable, the file belongs in its subfolder; a file
/// still at its old place is moved there. Nothing is deleted or overwritten. Without a reachable app folder,
/// everything stays at the old place, and no folder is created in an unreachable place.
public enum StorageLocation {
    /// The address to use for a file now.
    /// - Parameters:
    ///   - oldURL: where the file lay before the app folder was chosen.
    ///   - appFolder: the chosen app folder, nil when none is chosen.
    ///   - subfolder: the subfolder of the app folder for this kind of file.
    public static func resolve(oldURL: URL, appFolder: URL?, subfolder: AppFolder.Subfolder,
                               fileManager: FileManager = .default) throws -> URL {
        guard let appFolder else { return oldURL }
        let state = AppFolder.state(of: appFolder, fileManager: fileManager)
        if state == .unreachable { return oldURL }
        if state == .needsSubfolders { try AppFolder.create(in: appFolder, fileManager: fileManager) }

        let target = appFolder
            .appending(path: subfolder.folderName, directoryHint: .isDirectory)
            .appending(path: oldURL.lastPathComponent)
        guard fileManager.fileExists(atPath: oldURL.path) else { return target }
        if fileManager.fileExists(atPath: target.path) { return oldURL }
        try fileManager.moveItem(at: oldURL, to: target)
        return target
    }
}
