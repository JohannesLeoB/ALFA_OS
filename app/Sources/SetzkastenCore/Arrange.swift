import Foundation

/// Anordnen einer Auswahl. Reine Funktionen: Eingang Elemente, Ausgang neue Rechtecke.
/// Die Oberfläche wendet das Ergebnis an und legt einen Rückgängig-Schritt an.
public enum Arrangement: String, Sendable, CaseIterable {
    case alignLeft, alignTop, alignCenter, row, grid, pile, sameSize
}

public struct ArrangeOptions: Sendable {
    public var gap: Double = 32
    public var pileOffset: Double = 24
    public var snap: Double = 8
    public init(gap: Double = 32, pileOffset: Double = 24, snap: Double = 8) { self.gap = gap; self.pileOffset = pileOffset; self.snap = snap }
}

public func arrange(_ items: [Item], _ how: Arrangement, reference: ItemID? = nil, options: ArrangeOptions = .init()) -> [ItemID: Rect] {
    let movable = items.filter { !$0.locked }
    guard movable.count >= 2 else { return [:] }
    func snap(_ v: Double) -> Double { options.snap > 0 ? (v / options.snap).rounded() * options.snap : v }
    let minX = movable.map(\.rect.x).min()!, minY = movable.map(\.rect.y).min()!
    let maxX = movable.map(\.rect.maxX).max()!
    var out: [ItemID: Rect] = [:]
    switch how {
    case .alignLeft:
        for i in movable { var r = i.rect; r.x = minX; out[i.id] = r }
    case .alignTop:
        for i in movable { var r = i.rect; r.y = minY; out[i.id] = r }
    case .alignCenter:
        let cx = (minX + maxX) / 2
        for i in movable { var r = i.rect; r.x = snap(cx - r.w / 2); out[i.id] = r }
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

/// Kinder eines Rahmens oder einer Gruppe: alle Elemente, deren Mitte darin liegt.
public func children(of container: Item, in items: [Item]) -> [Item] {
    items.filter { item in
        guard item.id != container.id else { return false }
        if case .group = item.content { return false }          // Gruppen wandern nie in andere Container
        let c = item.rect.center
        return container.rect.contains(x: c.x, y: c.y)
    }
}
