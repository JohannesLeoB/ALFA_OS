import AppKit
import UniformTypeIdentifiers
import ALFAcolorCore
import BoardModel
import Document
import Exporters

/// Saves a mockup package. The whole board goes out, or only the selection when one is made.
/// The package comes from `MockupFormat`; this file only asks where to write it and reports a failure.
@MainActor
enum MockupExport {
    static func run(store: BoardStore) {
        let scope: ExchangeScope = store.selection.isEmpty ? .document : .items(Array(store.selection))
        let output: ExchangeOutput
        do {
            output = try MockupFormat().write(store.document, scope: scope)
        } catch {
            report(error)
            return
        }
        guard case .file(let name, _, let data) = output else { return }
        let panel = NSSavePanel()
        panel.message = String(localized: "export.panel.message")
        panel.allowedContentTypes = [.zip]
        panel.nameFieldStringValue = name
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                report(error)
            }
        }
    }

    /// Shows the reason in a sheet of the key window. Nothing is written after a failure.
    private static func report(_ error: any Error) {
        let alert = NSAlert()
        alert.messageText = String(localized: "export.failed.title")
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
}
