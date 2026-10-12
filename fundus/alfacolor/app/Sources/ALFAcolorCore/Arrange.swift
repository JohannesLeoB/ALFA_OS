import Foundation

/// Arranging a selection. Pure functions: items in, new rectangles out.
/// The UI applies the result and records an undo step.
public enum Arrangement: String, Sendable, CaseIterable {
    /// Aligns the left edges, the right edges, the horizontal centers.
    case alignLeft, alignRight, alignCenter
    /// Aligns the top edges, the bottom edges, the vertical centers.
    case alignTop, alignBottom, alignMiddle
    /// Spreads the items in a row, a grid or a pile.
    case row, grid, pile
    /// Gives every item the size of the reference item.
    case sameSize
    /// Moves every item's corner onto the nearest grid point, one item or more.
    case snapToGrid
}

public struct ArrangeOptions: Sendable {
    public var gap: Double = 32
    public var pileOffset: Double = 24
    public var snap: Double = 8
    public init(gap: Double = 32, pileOffset: Double = 24, snap: Double = 8) { self.gap = gap; self.pileOffset = pileOffset; self.snap = snap }
}

public func arrange(_ items: [Item], _ how: Arrangement, reference: ItemID? = nil, options: ArrangeOptions = .init()) -> [ItemID: Rect] {
    let movable = items.filter { !$0.locked }
    guard movable.count >= 2 || (how == .snapToGrid && !movable.isEmpty) else { return [:] }
    func snap(_ v: Double) -> Double { options.snap > 0 ? (v / options.snap).rounded() * options.snap : v }
    let minX = movable.map(\.rect.x).min()!, minY = movable.map(\.rect.y).min()!
    let maxX = movable.map(\.rect.maxX).max()!, maxY = movable.map(\.rect.maxY).max()!
    var out: [ItemID: Rect] = [:]
    switch how {
    case .alignLeft:
        for i in movable { var r = i.rect; r.x = minX; out[i.id] = r }
    case .alignRight:
        for i in movable { var r = i.rect; r.x = maxX - r.w; out[i.id] = r }
    case .alignTop:
        for i in movable { var r = i.rect; r.y = minY; out[i.id] = r }
    case .alignBottom:
        for i in movable { var r = i.rect; r.y = maxY - r.h; out[i.id] = r }
    case .alignCenter:
        let cx = (minX + maxX) / 2
        for i in movable { var r = i.rect; r.x = snap(cx - r.w / 2); out[i.id] = r }
    case .alignMiddle:
        let cy = (minY + maxY) / 2
        for i in movable { var r = i.rect; r.y = snap(cy - r.h / 2); out[i.id] = r }
    case .snapToGrid:
        for i in movable { var r = i.rect; r.x = snap(r.x); r.y = snap(r.y); out[i.id] = r }
    case .row:
        var x = minX
        for i in movable.sorted(by: { $0.rect.x < $1.rect.x }) { var r = i.rect; r.x = x; r.y = minY; out[i.id] = r; x += r.w + options.gap }
    case .grid:
        let cols = Int(Double(movable.count).squareRoot().rounded(.up))
        let cw = movable.map(\.rect.w).max()!, ch = movable.map(\.rect.h).max()!
        for (n, i) in movable.sorted(by: { ($0.rect.y, $0.rect.x) < ($1.rect.y, $1.rect.x) }).enumerated() {
            var r = i.rect; r.x = minX + Double(n % cols) * (cw + options.gap); r.y = minY + Double(n / cols) * (ch + options.gap); out[i.id] = r
        }
    case .pile:
        for (n, i) in movable.sorted(by: { $0.z < $1.z }).enumerated() {
            var r = i.rect; r.x = minX + Double(n) * options.pileOffset; r.y = minY + Double(n) * options.pileOffset; out[i.id] = r
        }
    case .sameSize:
        guard let ref = movable.first(where: { $0.id == reference }) ?? movable.last else { return [:] }
        for i in movable where !i.isContainer { var r = i.rect; r.w = ref.rect.w; r.h = ref.rect.h; out[i.id] = r }
    }
    return out
}

/// Children of a frame or group: all items whose center lies inside.
public func children(of container: Item, in items: [Item]) -> [Item] {
    items.filter { item in
        guard item.id != container.id else { return false }
        if case .group = item.content { return false }          // Groups never move into other containers
        let c = item.rect.center
        return container.rect.contains(x: c.x, y: c.y)
    }
}
