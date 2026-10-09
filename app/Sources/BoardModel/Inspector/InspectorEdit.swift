import ALFAcolorCore
import Geometry

/// A field of the inspector that changes the items.
public enum InspectorField: String, CaseIterable, Sendable {
    case x, y, width, height
}

/// The command for a field. One field is one command, so one entry is one undo step.
public enum InspectorEdit {
    /// The items that a field change can move or resize: not locked, and not on a locked layer.
    /// The commands skip the others, so the values of the fields must come from these items only.
    public static func movable(_ items: [Item], lockedLayers: Set<String>) -> [Item] {
        items.filter { !$0.locked && !lockedLayers.contains($0.layerID) }
    }

    /// The command that sets a field of the selection to `points`. X and Y move the selection box, so all items
    /// move together and the items inside a frame or group come along. Width and height give every item that size.
    /// Nil when nothing would change, when a size is not above zero, or when a value is beyond the number limits.
    public static func command(_ field: InspectorField, to points: Double, items: [Item]) -> Command? {
        guard points.isFinite, !items.isEmpty else { return nil }
        let ids = Set(items.map(\.id))
        switch field {
        case .x:
            guard abs(points) <= NumberLimit.coordinate else { return nil }
            let delta = points - items.map(\.rect.x).min()!
            return delta == 0 ? nil : .move(ids, dx: delta, dy: 0)
        case .y:
            guard abs(points) <= NumberLimit.coordinate else { return nil }
            let delta = points - items.map(\.rect.y).min()!
            return delta == 0 ? nil : .move(ids, dx: 0, dy: delta)
        case .width:
            return resize(items, to: points) { rect in rect.w != points ? Rect(x: rect.x, y: rect.y, w: points, h: rect.h) : nil }
        case .height:
            return resize(items, to: points) { rect in rect.h != points ? Rect(x: rect.x, y: rect.y, w: rect.w, h: points) : nil }
        }
    }

    private static func resize(_ items: [Item], to points: Double, _ change: (Rect) -> Rect?) -> Command? {
        guard points > 0, points <= NumberLimit.length else { return nil }
        var rects: [ItemID: Rect] = [:]
        for item in items {
            if let rect = change(item.rect) { rects[item.id] = rect }
        }
        return rects.isEmpty ? nil : .resize(rects)
    }
}
