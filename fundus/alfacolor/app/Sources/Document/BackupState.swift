import Foundation

/// Whether a backup can be read. A backup that cannot be read is listed with its actions and is never opened silently.
public enum BackupState: Equatable, Sendable {
    case readable
    case unreadable

    /// The actions offered for the backup, in the order the list shows them.
    public var actions: [UnreadableAction] {
        switch self {
        case .readable: []
        case .unreadable: UnreadableAction.allCases
        }
    }
}

/// What the user can do with an unreadable backup. Showing the file is the view's job; the core only names it.
public enum UnreadableAction: String, CaseIterable, Equatable, Sendable {
    /// Moves the backup into the folder `unreadable` of its document. Nothing is deleted.
    case setAside
    /// Shows the file in the Finder.
    case revealFile
    /// Leaves the backup where it is.
    case cancel
}
