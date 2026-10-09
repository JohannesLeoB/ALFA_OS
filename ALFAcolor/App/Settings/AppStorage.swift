import ALFAcolorCore
import Foundation

/// Where the app keeps its files now: in its subfolder of the app folder when that folder is reachable,
/// otherwise at the old place. A file at the old place is moved, never overwritten.
@MainActor
enum AppStorage {
    static func location(oldURL: URL, subfolder: AppFolder.Subfolder) throws -> URL {
        try StorageLocation.resolve(oldURL: oldURL, appFolder: PlaceStore.shared.appFolderURL(), subfolder: subfolder)
    }
}
