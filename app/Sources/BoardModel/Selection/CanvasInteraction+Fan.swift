import ALFAcolorCore
import Tokens

/// The colour fan over a swatch. A double click opens it, and a blade paints the selection.
extension CanvasInteraction {
    /// Opens the fan over a swatch that can change, and selects it. False for any other item, and for a swatch without a colour.
    @discardableResult
    public func openFan(_ id: ItemID) -> Bool {
        guard let item = store.item(id), isEditable(item), case .swatch(let hex, _) = item.content, RGB(hex: hex) != nil else { return false }
        store.select([id])
        fanItem = id
        return true
    }

    /// Closes the fan. The colours stay as they are.
    public func closeFan() {
        fanItem = nil
    }

    /// Paints the selection with a colour, as one undo step. Items without a colour, and locked items, stay as they are.
    /// Returns true when the document changed.
    @discardableResult
    public func paintSelection(hex: String) -> Bool {
        run(.setFill(store.selection, hex: hex))
    }

    /// True when the selection has an item that a colour can change. Items without a colour, and locked items, do not count.
    public var canPaintSelection: Bool {
        store.selectedItems.contains { item in
            guard isEditable(item) else { return false }
            switch item.content {
            case .shape, .swatch: return true
            default: return false
            }
        }
    }
}
