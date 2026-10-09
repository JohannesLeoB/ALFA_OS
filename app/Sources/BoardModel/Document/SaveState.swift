/// Where a document stands against its file.
public enum SaveState: Equatable, Sendable {
    /// The file holds the current state.
    case saved
    /// There are changes that are not in the file yet.
    case modified
    /// The last save failed.
    case failed
}
