import ALFAcolorCore
import Foundation

/// Where the app keeps its files now: in its subfolder of the app folder when that folder is reachable,
/// otherwise at the old place. A file at the old place is moved, never overwritten. When a file of the same
/// name already lies in the app folder, the user decides; a choice to keep the old file is remembered.
@MainActor
enum AppStorage {
    /// The key in UserDefaults for the old files the user chose to keep where they are.
    private static let keptKey = "keptOldFiles"

    static func location(oldURL: URL, subfolder: AppFolder.Subfolder) throws -> URL {
        let appFolder = PlaceStore.shared.appFolderURL()
        guard let conflict = StorageLocation.conflict(oldURL: oldURL, appFolder: appFolder, subfolder: subfolder) else {
            return try StorageLocation.resolve(oldURL: oldURL, appFolder: appFolder, subfolder: subfolder)
        }
        var kept = StorageKeptFiles(paths: UserDefaults.standard.stringArray(forKey: keptKey) ?? [])
        if kept.contains(oldURL) { return conflict.targetURL }

        let (url, choice) = try StorageConflictSheet.resolve(conflict)
        if choice == .keepTarget {
            kept.keep(oldURL)
            UserDefaults.standard.set(kept.paths, forKey: keptKey)
        }
        return url
    }
}
