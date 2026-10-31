import AppKit
import Mail
import PDFKit
import UniformTypeIdentifiers

@MainActor
enum AttachmentExport {
    static func pdf(_ data: Data, name: String) -> Data? {
        switch (name as NSString).pathExtension.lowercased() {
        case "pdf":
            return data
        case "txt":
            let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
            let info = NSPrintInfo.shared
            return MessagePDF.render(text: text, page: info.paperSize, margin: info.leftMargin)
        default:
            guard let image = NSImage(data: data), let page = PDFPage(image: image) else { return nil }
            let document = PDFDocument()
            document.insert(page, at: 0)
            return document.dataRepresentation()
        }
    }

    static func printAttachment(_ data: Data, name: String) -> Bool {
        guard let document = pdf(data, name: name) else { return false }
        return MessageExport.printPDF(document, name: name, scaling: .pageScaleDownToFit)
    }

    static func savePDF(_ data: Data, name: String) -> Bool {
        guard let document = pdf(data, name: name) else { return false }
        let panel = NSSavePanel()
        panel.appearance = ForeignContent.panel
        panel.allowedContentTypes = [.pdf]
        panel.isExtensionHidden = false
        panel.canSelectHiddenExtension = true
        panel.nameFieldStringValue = ((name as NSString).deletingPathExtension as NSString).appendingPathExtension("pdf") ?? name
        guard panel.runModal() == .OK, let url = panel.url else { return true }
        return (try? document.write(to: url)) != nil
    }

    static func save(_ data: Data, name: String) -> Bool {
        let panel = NSSavePanel()
        panel.appearance = ForeignContent.panel
        let type = UTType(filenameExtension: (name as NSString).pathExtension)
        if let type { panel.allowedContentTypes = [type] }
        panel.allowsOtherFileTypes = true
        panel.isExtensionHidden = false
        panel.canSelectHiddenExtension = true
        panel.nameFieldStringValue = name
        guard panel.runModal() == .OK, let url = panel.url else { return true }
        return (try? data.write(to: url)) != nil
    }
}
