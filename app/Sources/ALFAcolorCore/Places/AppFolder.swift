import Foundation

/// The reasons why the app folder cannot be set up.
public enum AppFolderError: Error, Equatable, Sendable {
    /// The chosen place is not an existing folder, for example a drive that is not connected.
    case unreachable
}

/// The app folder: the place the user chose for parts, styles, code blocks, prototypes, backup and autosave.
/// The subfolders are made inside a folder that exists. A missing folder is never made here, so that nothing
/// is written to another place when a drive is not there.
public enum AppFolder {
    /// The subfolders of the app folder. The names are the folder names on the disk.
    public enum Subfolder: String, CaseIterable, Sendable {
        case parts
        case styles
        case codeBlocks
        case prototypes
        case backup
        case autosave

        public var folderName: String {
            switch self {
            case .parts: "Bauteile"
            case .styles: "Styles"
            case .codeBlocks: "Code-Bl\u{F6}cke"
            case .prototypes: "Prototypen"
            case .backup: "Backup"
            case .autosave: "Autosave"
            }
        }
    }

    /// The state of a chosen app folder.
    public enum State: Equatable, Sendable {
        /// The folder exists and holds all subfolders.
        case ready
        /// The folder exists, but some subfolders are missing.
        case needsSubfolders
        /// The folder does not exist or is not a folder.
        case unreachable
    }

    /// Whether the folder exists and whether it holds all subfolders.
    public static func state(of root: URL, fileManager: FileManager = .default) -> State {
        guard isFolder(root, fileManager) else { return .unreachable }
        let complete = Subfolder.allCases.allSatisfy { isFolder(root.appending(path: $0.folderName), fileManager) }
        return complete ? .ready : .needsSubfolders
    }

    /// Makes the missing subfolders inside the folder. Existing subfolders and their content stay.
    public static func create(in root: URL, fileManager: FileManager = .default) throws {
        guard isFolder(root, fileManager) else { throw AppFolderError.unreachable }
        for subfolder in Subfolder.allCases {
            let url = root.appending(path: subfolder.folderName, directoryHint: .isDirectory)
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    private static func isFolder(_ url: URL, _ fileManager: FileManager) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
