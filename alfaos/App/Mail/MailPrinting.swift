import AppKit
import Mail
import PDFKit
import UniformTypeIdentifiers

@MainActor
enum MailPrinting {
    private static func document(_ model: MailModel, _ id: String) async -> MailDocument? {
        let info = NSPrintInfo.shared
        return await model.mailDocument(id) { MailPDF.render($0, page: info.paperSize, margin: info.leftMargin) }
    }

    static func printMail(_ model: MailModel, _ id: String) async {
        guard let document = await document(model, id) else { return }
        guard let pdf = PDFDocument(data: document.data),
              let operation = pdf.printOperation(for: NSPrintInfo.shared, scalingMode: .pageScaleNone, autoRotate: false) else {
            model.documentFailed(id)
            return
        }
        operation.jobTitle = document.name
        if let window = NSApp.keyWindow {
            operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        } else {
            operation.run()
        }
    }

    static func savePDF(_ model: MailModel, _ id: String) async {
        guard let document = await document(model, id) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = document.name
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try document.data.write(to: url)
        } catch {
            model.documentFailed(id)
            return
        }
        model.announce(.pdfSaved)
    }
}
