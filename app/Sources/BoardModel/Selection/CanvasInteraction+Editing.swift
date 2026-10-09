import Foundation
import ImageIO
import ALFAcolorCore

/// A text edit in progress: the item, its content before and the text typed so far.
public struct TextEdit: Equatable, Sendable {
    public var itemID: ItemID
    public var original: Content
    public var text: String

    /// The content with the typed text. A note keeps being a note and a text keeps its style.
    public var content: Content {
        switch original {
        case .note: .note(text: text)
        case .text(_, let style): .text(text: text, style: style)
        default: original
        }
    }

    /// The text of a content that can be edited, nil for any other.
    public static func text(of content: Content) -> String? {
        switch content {
        case .note(let text): text
        case .text(let text, _): text
        default: nil
        }
    }
}

/// Editing text in place, and the actions a double click starts.
extension CanvasInteraction {
    /// A double click at a point of the canvas. On a note or a text it starts editing; on a swatch it opens the colour fan;
    /// on an image without a readable file it asks for the file; elsewhere it does nothing.
    public func doubleClick(atCanvasX x: Double, y: Double) {
        let point = board(fromCanvasX: x, y: y)
        if let editing, let rect = store.item(editing.itemID)?.rect, rect.contains(x: point.x, y: point.y) { return }
        guard let hit = HitTest.item(atX: point.x, y: point.y, among: controller.drawnItems, zoom: controller.viewport.zoom, bandHeight: bandHeight),
              let item = store.item(hit) else { return }
        switch item.content {
        case .note, .text:
            store.select([hit])
            beginEditing(hit)
        case .swatch:
            openFan(hit)
        case .image(let assetID, _, _) where needsFile(assetID):
            store.select([hit])
            fileSearchRequest = hit
        default:
            break
        }
    }

    /// Starts editing the text of a note or a text item that can change. An edit in progress ends first.
    @discardableResult
    public func beginEditing(_ id: ItemID) -> Bool {
        if editing != nil { commitEdit() }
        guard let item = store.item(id), isEditable(item), let text = TextEdit.text(of: item.content) else { return false }
        resetGesture()
        editing = TextEdit(itemID: id, original: item.content, text: text)
        refreshDistances()
        return true
    }

    /// The text field reports the typed text.
    public func setEditText(_ text: String) {
        editing?.text = text
    }

    /// Ends the edit and keeps the text, as one undo step. Unchanged text is no step.
    public func commitEdit() {
        guard let session = editing else { return }
        editing = nil
        run(.setContent(session.itemID, session.content))
    }

    /// Ends what is in progress in the space being left: the text edit keeps its text there, a drag stops, the fan closes.
    func prepareSpaceChange() {
        commitEdit()
        closeFan()
        cancelGesture()
    }

    /// Ends the edit and drops the typed text.
    public func cancelEdit() {
        editing = nil
    }

    /// True when the image has no bytes in the document, or the bytes are no picture that ImageIO can read.
    private func needsFile(_ assetID: String) -> Bool {
        guard let entry = store.document.assets[assetID], let data = try? entry.data() else { return true }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0 else { return true }
        return CGImageSourceCopyPropertiesAtIndex(source, 0, nil) == nil
    }

    /// Puts the file the user found in place of the missing image: the bytes enter the document and the item points at them.
    /// The crop stays. One undo step. Returns false when the item is not an image or cannot change.
    @discardableResult
    public func replaceImage(of id: ItemID, with data: Data, fileExtension: String) -> Bool {
        fileSearchRequest = nil
        guard let item = store.item(id), isEditable(item), case .image(_, let crop, let fit) = item.content else { return false }
        let assetID = store.addAsset(data, fileExtension: fileExtension)
        return run(.setContent(id, .image(assetID: assetID, crop: crop, fit: fit)))
    }
}
