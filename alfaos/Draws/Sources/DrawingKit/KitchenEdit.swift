import Foundation

public struct Locus: Hashable, Sendable {
    public var run: Int
    public var item: Int
    public init(run: Int, item: Int) { self.run = run; self.item = item }

    public init?(id: String, prefix: String) {
        guard let slot = Kitchen.slot(id, prefix: prefix), let item = slot.item else { return nil }
        self.init(run: slot.run, item: item)
    }

    public func id(prefix: String) -> String { "\(prefix)r\(run)c\(item)" }
}

public enum Extent: String, CaseIterable, Sendable { case width, height, depth }

public enum Side: String, Sendable { case before, after }

public enum Step: String, Sendable { case left, right }

public enum Field: String, CaseIterable, Sendable { case grip, style, plinth, edge, front, carcass, worktop, plinthMaterial }

public enum Setting: Hashable, Sendable {
    case grip(GripStyle), style(FrontStyle), plinth(PlinthStyle), edge(Bool)
    case front(String), carcass(String), worktop(String), plinthMaterial(String)

    public static func make(_ field: Field, _ value: String) -> Setting? {
        switch field {
        case .grip: GripStyle(rawValue: value).map(Setting.grip)
        case .style: FrontStyle(rawValue: value).map(Setting.style)
        case .plinth: PlinthStyle(rawValue: value).map(Setting.plinth)
        case .edge: Bool(value).map(Setting.edge)
        case .front: .front(value)
        case .carcass: .carcass(value)
        case .worktop: .worktop(value)
        case .plinthMaterial: .plinthMaterial(value)
        }
    }

    public var field: Field {
        switch self {
        case .grip: .grip
        case .style: .style
        case .plinth: .plinth
        case .edge: .edge
        case .front: .front
        case .carcass: .carcass
        case .worktop: .worktop
        case .plinthMaterial: .plinthMaterial
        }
    }
}

public enum Split: Hashable, Sendable {
    case door, pair, drawers(Int), drawerDoor, appliance(Appliance), open, glass

    public static let presets: [Split] = [.door, .pair, .drawers(2), .drawers(3), .drawers(4), .drawerDoor,
                                          .appliance(.dishwasher), .open, .glass]

    public var name: String {
        switch self {
        case .door: "door"
        case .pair: "pair"
        case .drawers(let n): "drawers\(n)"
        case .drawerDoor: "drawerdoor"
        case .appliance(let a): a.rawValue
        case .open: "open"
        case .glass: "glass"
        }
    }

    public init?(name: String) {
        let key = name.lowercased()
        if let found = Self.presets.first(where: { $0.name == key }) { self = found; return }
        if key.hasPrefix("drawers"), let n = Int(key.dropFirst(7)) { self = .drawers(n); return }
        if let a = Appliance(rawValue: key) { self = .appliance(a); return }
        return nil
    }

    func fronts(_ pack: KitchenPack) throws -> [Front] {
        switch self {
        case .door: return [Front(type: .door, side: pack.door.side)]
        case .pair: return [Front(type: .door, side: .pair)]
        case .drawers(let n):
            guard pack.drawer.counts[String(n)] != nil else { throw KitchenError.edit("split", "no drawer split for \(n)") }
            return [Front(type: .drawers, count: n)]
        case .drawerDoor: return [Front(type: .drawers, count: 1, height: 2 * pack.drawer.min), Front(type: .door)]
        case .appliance(let a): return [Front(type: .appliance, appliance: a)]
        case .open: return [Front(type: .open)]
        case .glass: return [Front(type: .glass)]
        }
    }
}

public extension KitchenSpec {
    private func label(_ spot: Locus) -> String { spot.id(prefix: prefix ?? "") }

    private func items(_ run: Int) -> [Cabinet]? {
        if run >= 0, run < runs.count { return runs[run].items }
        return run == runs.count ? island?.items : nil
    }

    private func putting(_ run: Int, _ list: [Cabinet]) -> KitchenSpec {
        var next = self
        if run < runs.count { next.runs[run].items = list } else { next.island?.items = list }
        return next
    }

    func cabinet(_ spot: Locus) throws -> Cabinet {
        guard let list = items(spot.run), list.indices.contains(spot.item) else { throw KitchenError.edit(label(spot), "no such cabinet") }
        return list[spot.item]
    }

    func spots() -> [Locus] {
        all.indices.flatMap { run in all[run].items.indices.map { Locus(run: run, item: $0) } }
    }

    private func editing(_ spot: Locus, _ change: (inout Cabinet) throws -> Void) throws -> KitchenSpec {
        guard var list = items(spot.run), list.indices.contains(spot.item) else { throw KitchenError.edit(label(spot), "no such cabinet") }
        try change(&list[spot.item])
        return putting(spot.run, list)
    }

    private func checked(_ pack: KitchenPack) throws -> KitchenSpec {
        _ = try Kitchen.generate(self, pack: pack)
        return self
    }

    private static func positive(_ value: Double?, _ id: String, _ field: String) throws {
        if let value, !(value.isFinite && value > 0) { throw KitchenError.size(id, field) }
    }

    func set(_ spot: Locus, width: Double? = nil, height: Double? = nil, depth: Double? = nil) throws -> KitchenSpec {
        let id = label(spot)
        try Self.positive(width, id, "width"); try Self.positive(height, id, "height"); try Self.positive(depth, id, "depth")
        return try editing(spot) { cab in
            if let width { cab.width = width }
            if let height { cab.height = height }
            if let depth { cab.depth = depth }
        }
    }

    func resize(_ spot: Locus, _ axis: Extent, by delta: Double, pack: KitchenPack) throws -> KitchenSpec {
        let sizes = try Kitchen.sizes(self, pack: pack)
        guard sizes.indices.contains(spot.run), sizes[spot.run].indices.contains(spot.item) else {
            throw KitchenError.edit(label(spot), "no such cabinet")
        }
        let now = sizes[spot.run][spot.item]
        let value = (axis == .width ? now.width : axis == .height ? now.height : now.depth) + delta
        switch axis {
        case .width: return try set(spot, width: value).checked(pack)
        case .height: return try set(spot, height: value).checked(pack)
        case .depth: return try set(spot, depth: value).checked(pack)
        }
    }

    func insert(_ kind: CabinetKind, at spot: Locus, _ side: Side) throws -> KitchenSpec {
        guard var list = items(spot.run), list.indices.contains(spot.item) else { throw KitchenError.edit(label(spot), "no such cabinet") }
        list.insert(Cabinet(kind: kind), at: spot.item + (side == .after ? 1 : 0))
        return putting(spot.run, list)
    }

    func duplicate(_ spot: Locus) throws -> KitchenSpec {
        guard var list = items(spot.run), list.indices.contains(spot.item) else { throw KitchenError.edit(label(spot), "no such cabinet") }
        list.insert(list[spot.item], at: spot.item + 1)
        return putting(spot.run, list)
    }

    func remove(_ spot: Locus) throws -> KitchenSpec {
        guard var list = items(spot.run), list.indices.contains(spot.item) else { throw KitchenError.edit(label(spot), "no such cabinet") }
        if list.count == 1 {
            guard spot.run == runs.count else { throw KitchenError.edit(label(spot), "a run keeps at least one cabinet") }
            var next = self
            next.island = nil
            return next
        }
        list.remove(at: spot.item)
        return putting(spot.run, list)
    }

    private func block(_ list: [Cabinet], _ item: Int) -> Range<Int> {
        var start = item
        while start > 0, list[start].kind == .top { start -= 1 }
        var end = start + 1
        while end < list.count, list[end].kind == .top { end += 1 }
        return start..<end
    }

    func moveTarget(_ spot: Locus, _ step: Step) -> Locus? {
        guard let list = items(spot.run), list.indices.contains(spot.item), list[spot.item].kind != .top else { return nil }
        let mine = block(list, spot.item)
        if step == .left {
            guard mine.lowerBound > 0 else { return nil }
            return Locus(run: spot.run, item: block(list, mine.lowerBound - 1).lowerBound)
        }
        guard mine.upperBound < list.count else { return nil }
        return Locus(run: spot.run, item: mine.lowerBound + block(list, mine.upperBound).count)
    }

    func move(_ spot: Locus, _ step: Step) throws -> KitchenSpec {
        guard var list = items(spot.run), let target = moveTarget(spot, step) else {
            throw KitchenError.edit(label(spot), "cannot move \(step.rawValue)")
        }
        let mine = block(list, spot.item)
        let moving = Array(list[mine])
        list.removeSubrange(mine)
        list.insert(contentsOf: moving, at: target.item)
        return putting(spot.run, list)
    }

    func flipHinge(_ spot: Locus, pack: KitchenPack) throws -> KitchenSpec {
        let sizes = try Kitchen.sizes(self, pack: pack)
        let cab = try cabinet(spot)
        let width = sizes[spot.run][spot.item].width
        var stack = cab.fronts ?? Kitchen.make(pack.kinds[cab.kind.rawValue]?.front ?? "").map { [$0] } ?? []
        var flipped = false
        for k in stack.indices where stack[k].type == .door || stack[k].type == .glass {
            let now = stack[k].side ?? (width >= pack.door.pairFrom ? .pair : pack.door.side)
            guard now != .pair else { continue }
            stack[k].side = now == .left ? .right : .left
            flipped = true
        }
        guard flipped else { throw KitchenError.edit(label(spot), "no single door to flip") }
        return try editing(spot) { $0.fronts = stack }
    }

    func setSplit(_ spot: Locus, _ split: Split, pack: KitchenPack) throws -> KitchenSpec {
        let fronts = try split.fronts(pack)
        return try editing(spot) { $0.fronts = fronts }.checked(pack)
    }

    func setType(_ spot: Locus, _ kind: CabinetKind, pack: KitchenPack) throws -> KitchenSpec {
        try editing(spot) { cab in cab.kind = kind; cab.fronts = nil }.checked(pack)
    }

    func overriding(_ spot: Locus, _ setting: Setting) throws -> KitchenSpec {
        try Self.vet(setting, label(spot))
        return try editing(spot) { cab in
            var features = cab.features ?? Features(), materials = cab.materials ?? Materials()
            Self.put(setting, &features, &materials)
            cab.features = features.isEmpty ? nil : features
            cab.materials = materials.isEmpty ? nil : materials
        }
    }

    func sharing(_ setting: Setting) throws -> KitchenSpec {
        try Self.vet(setting, "kitchen")
        var next = self
        var features = features ?? Features(), materials = materials ?? Materials()
        Self.put(setting, &features, &materials)
        next.features = features.isEmpty ? nil : features
        next.materials = materials.isEmpty ? nil : materials
        return next
    }

    func resetToShared(_ spot: Locus, _ field: Field? = nil) throws -> KitchenSpec {
        try editing(spot) { cab in
            guard let field else {
                cab.features = nil; cab.materials = nil; cab.material = nil; cab.frontMaterial = nil
                return
            }
            var features = cab.features ?? Features(), materials = cab.materials ?? Materials()
            switch field {
            case .grip: features.grip = nil
            case .style: features.style = nil
            case .plinth: features.plinth = nil
            case .edge: features.edge = nil
            case .front: materials.front = nil; cab.frontMaterial = nil
            case .carcass: materials.carcass = nil; cab.material = nil
            case .worktop: materials.worktop = nil
            case .plinthMaterial: materials.plinth = nil
            }
            cab.features = features.isEmpty ? nil : features
            cab.materials = materials.isEmpty ? nil : materials
        }
    }

    private static func vet(_ setting: Setting, _ id: String) throws {
        switch setting {
        case .front(let c), .carcass(let c), .worktop(let c), .plinthMaterial(let c):
            guard !c.trimmingCharacters(in: .whitespaces).isEmpty else { throw KitchenError.unknown(id, "material") }
        default: break
        }
    }

    private static func put(_ setting: Setting, _ f: inout Features, _ m: inout Materials) {
        switch setting {
        case .grip(let v): f.grip = v
        case .style(let v): f.style = v
        case .plinth(let v): f.plinth = v
        case .edge(let v): f.edge = v
        case .front(let v): m.front = v
        case .carcass(let v): m.carcass = v
        case .worktop(let v): m.worktop = v
        case .plinthMaterial(let v): m.plinth = v
        }
    }
}
