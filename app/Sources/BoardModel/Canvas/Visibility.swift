import Foundation
import ALFAcolorCore

/// Which items of a space get a view, and in which order they are drawn.
public enum Visibility {
    /// The ring around the visible part that still gets views, in canvas points. Views that are about to
    /// scroll in are ready, and an item is not rebuilt for each small move.
    public static let margin = 256.0

    /// The items to draw, from back to front: by layer (first layer at the bottom), then by `z`, then by
    /// place in the list. Hidden items, items on a hidden layer and items outside the visible part
    /// plus the margin are left out. An item on a layer that does not exist counts as visible.
    public static func drawn(in space: Space, viewport: Viewport, canvas size: CanvasSize, margin: Double = Visibility.margin) -> [Item] {
        guard viewport.isValid, size.isUsable, margin.isFinite else { return [] }
        let reach = max(margin, 0) / viewport.zoom
        let window = viewport.visibleRect(in: size)
        let area = Rect(x: window.x - reach, y: window.y - reach, w: window.w + 2 * reach, h: window.h + 2 * reach)
        let order = layerOrder(of: space)
        let hiddenLayers = Set(space.layers.filter { !$0.visible }.map(\.id))
        var found: [(item: Item, layer: Int, place: Int)] = []
        for (place, item) in space.items.enumerated() {
            guard !item.hidden, !hiddenLayers.contains(item.layerID), item.rect.isFinite, item.rect.intersects(area) else { continue }
            found.append((item, order[item.layerID] ?? -1, place))
        }
        found.sort { ($0.layer, $0.item.z, $0.place) < ($1.layer, $1.item.z, $1.place) }
        return found.map(\.item)
    }

    /// The box around the items with these IDs that can be seen (not hidden, layer not hidden).
    /// nil for no IDs or no visible item. `ids` nil takes all items of the space.
    public static func bounds(in space: Space, of ids: Set<ItemID>? = nil) -> Rect? {
        let hiddenLayers = Set(space.layers.filter { !$0.visible }.map(\.id))
        var box: Rect?
        for item in space.items where !item.hidden && !hiddenLayers.contains(item.layerID) && item.rect.isFinite {
            if let ids, !ids.contains(item.id) { continue }
            box = box.map { $0.union(item.rect) } ?? item.rect
        }
        return box
    }

    private static func layerOrder(of space: Space) -> [String: Int] {
        Dictionary(space.layers.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
}
