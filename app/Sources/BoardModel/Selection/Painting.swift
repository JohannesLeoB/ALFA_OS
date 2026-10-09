import ALFAcolorCore

/// What a colour can change. Shapes and swatches take a colour; notes, images, code and text do not.
public enum Painting {
    /// True when a colour can change at least one of these items. Items that `editable` refuses do not count.
    public static func canPaint(_ items: [Item], editable: (Item) -> Bool) -> Bool {
        items.contains { item in
            guard editable(item) else { return false }
            switch item.content {
            case .shape, .swatch: return true
            default: return false
            }
        }
    }
}

extension BoardStore {
    /// True when the selection holds an item that a colour can change. Locked items and items on locked layers do not count.
    public var canPaintSelection: Bool {
        let lockedLayers = Set(activeSpace?.layers.filter(\.locked).map(\.id) ?? [])
        return Painting.canPaint(selectedItems) { !$0.locked && !lockedLayers.contains($0.layerID) }
    }
}
