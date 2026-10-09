import AppKit
import Document
import Importers

/// Opens a copy of the starter document from the app bundle. The file in the bundle is never changed.
/// The copy goes into the folder "starter" in the Application Support folder of the app.
@MainActor
enum StarterOpener {
    static func open() {
        do {
            guard let source = Bundle.main.url(forResource: StarterDuplicate.bundleName, withExtension: DocumentPackage.fileExtension) else { return }
            let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let copy = try StarterDuplicate.copy(of: source, into: support.appending(path: "starter", directoryHint: .isDirectory))
            NSDocumentController.shared.openDocument(withContentsOf: copy, display: true) { _, _, error in
                if let error { NSApplication.shared.presentError(error) }
            }
        } catch {
            NSApplication.shared.presentError(error)
        }
    }
}
