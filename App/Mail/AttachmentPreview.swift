import AppKit
import QuickLookUI

final class AttachmentPreview: NSObject, QLPreviewPanelDataSource, @unchecked Sendable {
    static let shared = AttachmentPreview()
    private var file: URL?

    @MainActor
    static func show(_ data: Data, name: String) -> Bool {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = folder.appendingPathComponent((name as NSString).lastPathComponent)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: url)
        } catch {
            return false
        }
        shared.file = url
        guard let panel = QLPreviewPanel.shared() else { return false }
        panel.dataSource = shared
        panel.reloadData()
        panel.makeKeyAndOrderFront(nil)
        return true
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        file == nil ? 0 : 1
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        file.map { $0 as NSURL }
    }
}
