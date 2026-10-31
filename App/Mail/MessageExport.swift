import AppKit
import Hub
import Mail
import PDFKit
import UniformTypeIdentifiers

@MainActor
enum MessageExport {
    static func render(_ message: OpenMessage) -> Data? {
        let info = NSPrintInfo.shared
        let store = TemplateStore()
        guard let template = store.current.flatMap(store.text),
              let html = MessagePDF.html(template: template, message: message).data(using: .utf8),
              let styled = try? NSAttributedString(data: html, options: [.documentType: NSAttributedString.DocumentType.html,
                                                                         .characterEncoding: String.Encoding.utf8.rawValue],
                                                   documentAttributes: nil) else {
            return MessagePDF.render(message, page: info.paperSize, margin: info.leftMargin)
        }
        return MessagePDF.render(styled, page: info.paperSize, margin: info.leftMargin)
    }

    static func printMail(_ inbox: InboxState, _ id: String) async {
        guard let document = await inbox.mailDocument(id, render: render) else { return }
        if !printPDF(document.data, name: document.name, scaling: .pageScaleNone) { inbox.documentFailed(id) }
    }

    static func printDraft(_ inbox: InboxState, _ id: UUID) {
        guard let document = inbox.draftDocument(id, render: render) else { return }
        if !printPDF(document.data, name: document.name, scaling: .pageScaleNone) { inbox.announce(.pdfFailed) }
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
        panel.isExtensionHidden = false
        panel.canSelectHiddenExtension = true
        panel.nameFieldStringValue = document.name
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try document.data.write(to: url.pathExtension.isEmpty ? url.appendingPathExtension("pdf") : url)
        } catch {
            inbox.documentFailed(id)
            return
        }
        inbox.announce(.pdfSaved)
    }
}
