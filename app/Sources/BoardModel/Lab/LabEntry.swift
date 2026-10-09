import Foundation
import ALFAcolorCore

/// The code card that the lab key opens. The key works on the selected code card. Without one, it makes an empty card.
public enum LabEntry {
    /// The size of a new empty card, in board points.
    public static let newCardWidth = 720.0
    public static let newCardHeight = 480.0

    /// The code card that the lab opens for.
    /// A selected code card is used as it is, and nothing changes. The topmost one wins when several are selected.
    /// Otherwise one command adds an empty code card in the middle of the visible canvas, so one undo step takes it back.
    @MainActor
    public static func card(in controller: CanvasController) throws -> ItemID {
        let store = controller.store
        if let selected = store.selectedItems.last(where: isCode) {
            return selected.id
        }
        let layerID = store.activeSpace?.layers.first(where: { !$0.locked })?.id ?? "standard"
        let center = controller.viewport.boardPoint(canvasX: controller.size.width / 2, canvasY: controller.size.height / 2)
        let rect = Rect(x: center.x - newCardWidth / 2, y: center.y - newCardHeight / 2, w: newCardWidth, h: newCardHeight)
        let card = Item(title: "", content: .code(language: .html, files: [:], previewWidth: nil), rect: rect, layerID: layerID)
        try store.perform(.insert([card]))
        return card.id
    }

    private static func isCode(_ item: Item) -> Bool {
        if case .code = item.content { return true }
        return false
    }
}
