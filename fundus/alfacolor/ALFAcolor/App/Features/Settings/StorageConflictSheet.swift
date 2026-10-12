import AppKit
import ALFAcolorCore

/// The dialog that asks what happens when a file meets a file of the same name in the app folder. It offers four
/// choices and never overwrites on its own. The first button, keeping the file in the app folder, is the default.
@MainActor
enum StorageConflictSheet {
    /// Asks until the choice can be carried out, then carries it out.
    /// - Returns: the address of the file now, and the choice the user made.
    static func resolve(_ conflict: StorageConflict) throws -> (url: URL, choice: StorageChoice) {
        var name = conflict.oldURL.lastPathComponent
        var problem: String?
        while true {
            let field = NSTextField(string: name)
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = String(localized: "storage.conflict.title")
            alert.informativeText = problem ?? String(localized: "storage.conflict.info")
            alert.addButton(withTitle: String(localized: "storage.conflict.keep"))
            alert.addButton(withTitle: String(localized: "storage.conflict.replace"))
            alert.addButton(withTitle: String(localized: "storage.conflict.setAside"))
            alert.addButton(withTitle: String(localized: "storage.conflict.rename"))
            alert.accessoryView = field

            let choice: StorageChoice
            switch alert.runModal() {
            case .alertFirstButtonReturn: choice = .keepTarget
            case .alertSecondButtonReturn: choice = .replace
            case .alertThirdButtonReturn: choice = .setAside
            default:
                name = field.stringValue
                choice = .rename(name)
            }
            do {
                return (try StorageLocation.settle(conflict, with: choice), choice)
            } catch StorageConflictError.nameTaken {
                problem = String(localized: "storage.conflict.nameTaken")
            } catch StorageConflictError.invalidName {
                problem = String(localized: "storage.conflict.invalidName")
            }
        }
    }
}
