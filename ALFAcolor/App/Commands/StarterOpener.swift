import AppKit
import Document
import Importers

/// Opens a copy of the starter document from the app bundle. The file in the bundle is never changed.
/// The copy goes into the folder "starter" in the Application Support folder of the app.
@MainActor
enum StarterOpener {
    static func open() {
        do {
            guard let source = Bundle.main.url(forResource: StarterDuplicate.bundleName, withExtension: DocumentPackage.fileExtension) else {
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = String(localized: "starter.missing")
                alert.runModal()
                return
            }
            let folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appending(path: "starter", directoryHint: .isDirectory)
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
