import ALFAcolorCore

/// What the inspector shows for a selection: the values that the items share, or `mixed`.
public struct Inspection: Equatable, Sendable {
    public var count: Int
    public var kind: SharedValue<ItemKind>
    /// Position and size in points, as the items have them.
    public var x: SharedValue<Double>
    public var y: SharedValue<Double>
    public var width: SharedValue<Double>
    public var height: SharedValue<Double>
    public var layerID: SharedValue<String>
    public var locked: SharedValue<Bool>
    public var hidden: SharedValue<Bool>
    /// The aspect ratio of a single item. Nil for none or for several items.
    public var ratio: AspectRatio?

    public init(items: [Item]) {
        count = items.count
        kind = SharedValue(items.map { ItemKind($0.content) })
        x = SharedValue(items.map(\.rect.x))
        y = SharedValue(items.map(\.rect.y))
        width = SharedValue(items.map(\.rect.w))
        height = SharedValue(items.map(\.rect.h))
        layerID = SharedValue(items.map(\.layerID))
        locked = SharedValue(items.map(\.locked))
        hidden = SharedValue(items.map(\.hidden))
        ratio = items.count == 1 ? AspectRatio(width: items[0].rect.w, height: items[0].rect.h) : nil
    }
}
