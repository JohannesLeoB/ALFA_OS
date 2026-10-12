import AppKit
import UniformTypeIdentifiers
import ALFAcolorCore
import BoardModel
import Document
import Exporters

/// Saves the document as a mockup package or as a PDF sheet. The whole board goes out, or only the selection when one is made.
/// The files come from `MockupFormat` and `SheetFormat`; this file asks for the format, asks where to write, and reports a failure.
@MainActor
enum MockupExport {
    /// What the dialog returns: the format and, for the sheet, the page size.
    private struct Choice {
        let sheet: Bool
        let paper: SheetPaper
    }

    static func run(store: BoardStore) {
        guard let choice = askChoice() else { return }
        let scope: ExchangeScope = store.selection.isEmpty ? .document : .items(Array(store.selection))
        let format: any ExchangeFormat = choice.sheet ? SheetFormat(paper: choice.paper) : MockupFormat()
        let output: ExchangeOutput
        do {
            output = try format.write(store.document, scope: scope)
        } catch {
            report(error)
            return
        }
        guard case .file(let name, let type, let data) = output else { return }
        let panel = NSSavePanel()
        panel.message = String(localized: choice.sheet ? "export.panel.sheet" : "export.panel.message")
        panel.allowedContentTypes = [type]
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

    /// Asks for the format and the page size. Nil when the user cancels.
    private static func askChoice() -> Choice? {
        let alert = NSAlert()
        alert.messageText = String(localized: "export.choose.message")
        alert.addButton(withTitle: String(localized: "export.choose.next"))
        alert.addButton(withTitle: String(localized: "export.choose.cancel"))

        let format = NSPopUpButton(frame: .zero, pullsDown: false)
        format.addItems(withTitles: [String(localized: "exchange.mockup.name"), String(localized: "exchange.sheet.name")])
        let paper = NSPopUpButton(frame: .zero, pullsDown: false)
        paper.addItems(withTitles: [String(localized: "export.paper.a4"), String(localized: "export.paper.a3")])
        let grid = NSGridView(views: [
            [NSTextField(labelWithString: String(localized: "export.choose.format")), format],
            [NSTextField(labelWithString: String(localized: "export.choose.paper")), paper],
        ])
        grid.rowSpacing = 8
        grid.columnSpacing = 8
        grid.frame = NSRect(origin: .zero, size: grid.fittingSize)
        alert.accessoryView = grid

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return Choice(sheet: format.indexOfSelectedItem == 1, paper: paper.indexOfSelectedItem == 1 ? .a3 : .a4)
    }

    /// Shows the reason in a sheet of the key window. Nothing is written after a failure.
    private static func report(_ error: any Error) {
        let alert = NSAlert()
        alert.messageText = String(localized: "export.failed.title")
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
}
