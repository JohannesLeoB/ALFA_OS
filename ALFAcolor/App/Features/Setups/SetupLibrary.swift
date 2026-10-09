import Foundation
import Observation
import ALFAcolorCore
import BoardModel

/// The setups the user saved. They are kept in Application Support, next to the app's other files.
@MainActor
@Observable
final class SetupLibrary {
    static let shared = SetupLibrary()

    private(set) var saved: [Setup]
    private let store: SetupStore

    init(store: SetupStore = .applicationDefault) {
        self.store = store
        saved = store.load()
    }

    /// Adds a setup and writes the list. A write that fails keeps the setup for this session only.
    func add(_ setup: Setup) {
        saved.append(setup)
        try? store.save(saved)
    }
}

extension SetupStore {
    /// `setups.json` in the Styles folder of the app folder, or in the Application Support folder of the app
    /// while no app folder is reachable.
    @MainActor
    static var applicationDefault: SetupStore {
        let support = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                    appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        let folder = support.appendingPathComponent("ALFAcolor", isDirectory: true)
        let old = folder.appendingPathComponent("setups.json")
        let url = (try? AppStorage.location(oldURL: old, subfolder: .styles)) ?? old
        return SetupStore(url: url)
    }
}
