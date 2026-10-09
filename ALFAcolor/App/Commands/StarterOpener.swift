import AppKit
import ALFAcolorCore
import Document
import Importers

/// Opens a copy of the starter document from the app bundle. The file in the bundle is never changed.
/// The copy goes into the folder "starter" in the Application Support folder of the app.
@MainActor
enum StarterOpener {
    /// The name of the example document in the bundle, without the extension.
    static let exampleName = "Example"

    /// Opens a copy of the bundled document `bundleName`. The starter document is the default.
    static func open(_ bundleName: String = StarterDuplicate.bundleName) {
        do {
            guard let source = Bundle.main.url(forResource: bundleName, withExtension: DocumentPackage.fileExtension) else {
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = String(localized: "starter.missing")
                alert.runModal()
                return
            }
            let oldFolder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appending(path: "starter", directoryHint: .isDirectory)
            let folder = try AppStorage.location(oldURL: oldFolder, subfolder: .prototypes)
            // The copy made by an earlier call is opened again, so that each call does not add one more.
            let earlier = folder.appending(path: source.lastPathComponent)
            let copy = FileManager.default.fileExists(atPath: earlier.path) ? earlier : try StarterDuplicate.copy(of: source, into: folder)
            NSDocumentController.shared.openDocument(withContentsOf: copy, display: true) { _, _, error in
                if let error { NSApplication.shared.presentError(error) }
            }
        } catch {
            NSApplication.shared.presentError(error)
        }
    }
}
