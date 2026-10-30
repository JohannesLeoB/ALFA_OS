import AppKit
import Mail
import PDFKit
import UniformTypeIdentifiers

@MainActor
enum MessageExport {
    static func render(_ message: OpenMessage) -> Data? {
        let info = NSPrintInfo.shared
        return MessagePDF.render(message, page: info.paperSize, margin: info.leftMargin)
    }

    static func printMail(_ inbox: InboxState, _ id: String) async {
        guard let document = await inbox.mailDocument(id, render: render) else { return }
        if !printPDF(document.data, name: document.name, scaling: .pageScaleNone) { inbox.documentFailed(id) }
    }

    @discardableResult
    static func printPDF(_ data: Data, name: String, scaling: PDFPrintScalingMode) -> Bool {
        guard let pdf = PDFDocument(data: data),
              let operation = pdf.printOperation(for: NSPrintInfo.shared, scalingMode: scaling, autoRotate: false) else { return false }
        operation.jobTitle = name
        if let window = NSApp.keyWindow {
            operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        } else {
            operation.run()
        }
        return true
    }

    static func savePDF(_ inbox: InboxState, _ id: String) async {
        guard let document = await inbox.mailDocument(id, render: render) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = document.name
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try document.data.write(to: url)
        } catch {
            inbox.documentFailed(id)
            return
        }
        inbox.announce(.pdfSaved)
    }
}
