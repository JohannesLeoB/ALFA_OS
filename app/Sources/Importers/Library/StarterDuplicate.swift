import Foundation

/// Copies of the starter document. The app opens a copy, and never the file in its bundle.
public enum StarterDuplicate {
    /// The name of the starter document in the bundle, without the extension.
    public static let bundleName = "Bausteine"

    /// Copies the package at `source` into `folder`, under its own name. Creates the folder when it is missing.
    /// A name that is taken gets a number before the extension: "Bausteine 2", "Bausteine 3" and so on.
    /// Returns the URL of the copy.
    public static func copy(of source: URL, into folder: URL, fileManager: FileManager = .default) throws -> URL {
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = freeURL(for: source, in: folder, fileManager: fileManager)
        try fileManager.copyItem(at: source, to: destination)
        return destination
    }

    /// The first URL in `folder` that no file has yet, with the name of `source`.
    static func freeURL(for source: URL, in folder: URL, fileManager: FileManager) -> URL {
        let base = source.deletingPathExtension().lastPathComponent
        let fileExtension = source.pathExtension
        var candidate = folder.appending(path: source.lastPathComponent)
        var number = 1
        while fileManager.fileExists(atPath: candidate.path) {
            number += 1
            candidate = folder.appending(path: "\(base) \(number)").appendingPathExtension(fileExtension)
        }
        return candidate
    }
}
