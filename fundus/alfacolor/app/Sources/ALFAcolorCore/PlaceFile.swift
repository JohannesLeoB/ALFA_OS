import Foundation

/// What the app finds in the file that keeps the places.
public enum PlaceFileState: Equatable, Sendable {
    /// There is no file yet. The list starts empty.
    case missing
    /// The file holds a place list.
    case readable(PlaceRegistry)
    /// The file exists but is not a place list. Nothing is written over it.
    case unreadable
}

/// Reads the place file and sets an unreadable one aside. The file itself is never overwritten here.
public enum PlaceFile {
    /// The state of the file at this address.
    public static func load(from url: URL, fileManager: FileManager = .default) -> PlaceFileState {
        guard fileManager.fileExists(atPath: url.path) else { return .missing }
        guard let data = try? Data(contentsOf: url),
              let registry = try? JSONDecoder().decode(PlaceRegistry.self, from: data) else {
            return .unreadable
        }
        return .readable(registry)
    }

    /// Renames the file next to itself to `<name>.kaputt-<yyyy-MM-dd>.json`, using the date given. A name that is
    /// taken gets a counter (`-2`, `-3`, ...), so no file is overwritten. Returns the new address.
    @discardableResult
    public static func setAside(_ url: URL, date: Date, fileManager: FileManager = .default) throws -> URL {
        let base = url.deletingPathExtension().lastPathComponent
        let stamp = dayFormatter.string(from: date)
        let folder = url.deletingLastPathComponent()
        var counter = 1
        var target: URL
        repeat {
            let suffix = counter == 1 ? "" : "-\(counter)"
            target = folder.appending(path: "\(base).kaputt-\(stamp)\(suffix).json")
            counter += 1
        } while fileManager.fileExists(atPath: target.path)
        try fileManager.moveItem(at: url, to: target)
        return target
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
