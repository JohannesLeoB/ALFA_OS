import Foundation

/// The file of the grid templates, in the Application Support folder of the app. The folder is created when it is missing.
enum GridTemplateFile {
    static func url() throws -> URL {
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                  appropriateFor: nil, create: true)
        let folder = support.appending(path: "ALFAcolor", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appending(path: "raster-vorlagen.json")
    }
}
