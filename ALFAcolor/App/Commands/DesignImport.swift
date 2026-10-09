import AppKit
import UniformTypeIdentifiers
import ALFAcolorCore
import BoardModel
import Document
import Exporters
import Importers

/// Brings a delivery from the design side into the open document, and writes the contract back.
/// The panels live here; reading, checking and placing are in Importers and Exporters.
@MainActor
enum DesignImport {
    /// Asks for a ZIP, reads it and shows the review sheet. Nothing is changed before "Apply".
    static func run(store: BoardStore) {
        let panel = NSOpenPanel()
        panel.message = String(localized: "delivery.panel.message")
        panel.allowedContentTypes = [.zip]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let delivery = try DeliveryReader.read(try Data(contentsOf: url), now: .now)
                DeliverySheet.present(delivery, store: store, in: NSApp.keyWindow)
            } catch {
                DeliverySheet.report(error)
            }
        }
    }

    /// Writes the contract of the document as a ZIP. Nothing is written after a failure.
    static func exportContract(store: BoardStore) {
        let output: ExchangeOutput
        do {
            output = try ContractFormat().write(store.document, scope: .document)
        } catch {
            DeliverySheet.report(error)
            return
        }
        guard case .file(let name, let type, let data) = output else { return }
        let panel = NSSavePanel()
        panel.message = String(localized: "export.contract.panel")
        panel.allowedContentTypes = [type]
        panel.nameFieldStringValue = name
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                DeliverySheet.report(error)
            }
        }
    }
}
