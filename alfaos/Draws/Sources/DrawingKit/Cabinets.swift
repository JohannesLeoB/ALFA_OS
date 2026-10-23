import Foundation

public struct Kitchen: Sendable {
    public struct Info: Sendable, Equatable {
        public var run: Int
        public var length: Double
        public var cabinets: Int
    }

    public var parts: [Part] = []
    public var units: [Unit] = []
    public var runs: [Info] = []
    public var materials: [String] = []

    public static func slot(_ id: String, prefix: String) -> (run: Int, item: Int?)? {
        guard id.hasPrefix(prefix + "r") else { return nil }
        let rest = id.dropFirst(prefix.count + 1)
        let digits = rest.prefix { $0.isNumber }
        guard let run = Int(digits) else { return nil }
        let tail = rest.dropFirst(digits.count)
        guard let mark = tail.first, "cwp".contains(mark) else { return nil }
        guard mark == "c" else { return (run, nil) }
        guard let item = Int(tail.dropFirst().prefix { $0.isNumber }) else { return nil }
        return (run, item)
    }

    public struct Size: Sendable, Equatable {
        public var width: Double
        public var height: Double
        public var depth: Double
        public init(width: Double, height: Double, depth: Double) { self.width = width; self.height = height; self.depth = depth }
    }

    public static func sizes(_ spec: KitchenSpec, pack: KitchenPack) throws -> [[Size]] {
        try spec.all.enumerated().map { i, run in
            try layout(run, index: i, pack: pack).map { Size(width: $0.w, height: $0.h, depth: $0.d) }
        }
    }

    public static func owns(_ id: String, prefix: String) -> Bool { slot(id, prefix: prefix) != nil }

    struct Frame {
        var ox: Double, oy: Double, turn: Int
        var c: Double { [1, 0, -1, 0][turn / 90] }
        var s: Double { [0, 1, 0, -1][turn / 90] }
        func point(_ u: Double, _ v: Double) -> (x: Double, y: Double) { (ox + u * c - v * s, oy + u * s + v * c) }
    }

    struct Slot {
        var index: Int
        var cab: Cabinet
        var kind: KitchenPack.KindPack
        var u0: Double, u1: Double, h: Double, d: Double, z0: Double
        var w: Double { u1 - u0 }
        var corner: Bool { kind.cornerDepths != nil }
        var stacked: Bool { kind.mount == "stack" }
    }

    struct Leaf {
        var front: Front
        var side: HingeSide
        var height: Double
        var top: Double
        var index: Int
        var drawer: Bool { front.type == .drawers }
    }

    public static func generate(_ spec: KitchenSpec, pack: KitchenPack) throws -> Kitchen {
        let runs = spec.all
        guard !runs.isEmpty, runs.allSatisfy({ !$0.items.isEmpty }) else { throw KitchenError.empty }
        let prefix = spec.prefix ?? ""
        let ft = pack.front.thickness
        guard let base = pack.kinds[CabinetKind.base.rawValue] else { throw KitchenError.unknown("pack", CabinetKind.base.rawValue) }
        let wallLine = ft + base.depth
        var out = Kitchen()
        var frames: [Frame] = [], layouts: [[Slot]] = []
        for (i, run) in runs.enumerated() {
            var turn = run.turn ?? 0
            let origin: KitchenPoint
            if let given = run.origin {
                origin = given
            } else {
                guard i > 0, i <= spec.runs.count - 1, let last = layouts[i - 1].last, last.corner else { throw KitchenError.join(i) }
                let p = frames[i - 1].point(last.u1 - wallLine, wallLine - last.d - ft)
                origin = KitchenPoint(x: p.x, y: p.y)
                let derived = (frames[i - 1].turn + 270) % 360
                guard run.turn == nil || run.turn == derived else { throw KitchenError.turn(run.turn ?? 0) }
                turn = derived
            }
            guard [0, 90, 180, 270].contains(turn) else { throw KitchenError.turn(turn) }
            frames.append(Frame(ox: origin.x, oy: origin.y, turn: turn))
            layouts.append(try layout(run, index: i, pack: pack))
        }
        var used = Set<String>()
        for (i, slots) in layouts.enumerated() {
            try emit(slots, run: i, joined: runs[i].origin == nil, frame: frames[i], spec: spec, pack: pack, prefix: prefix,
                     wallLine: wallLine, into: &out, used: &used)
            let main = slots.filter { !$0.stacked }
            out.runs.append(Info(run: i, length: main.reduce(0) { $0 + $1.w }, cabinets: slots.count))
        }
        out.materials = used.sorted()
        try overlaps(out.parts, prefix: prefix)
        return out
    }

    static func size(_ value: Double?, _ fallback: Double, _ id: String, _ field: String) throws -> Double {
        let v = value ?? fallback
        guard v.isFinite, v > 0 else { throw KitchenError.size(id, field) }
        return v
    }

    static func layout(_ run: KitchenRun, index: Int, pack: KitchenPack) throws -> [Slot] {
        var slots: [Slot] = []
        var cursor = 0.0
        for (n, cab) in run.items.enumerated() {
            let id = "r\(index)c\(n)"
            guard let kind = pack.kinds[cab.kind.rawValue] else { throw KitchenError.unknown(id, cab.kind.rawValue) }
            var host: Slot?
            if kind.mount == "stack" {
                guard let previous = slots.last, previous.kind.carries == true else { throw KitchenError.host(id) }
                host = previous
            }
            let w = try size(cab.width, host?.w ?? kind.width, id, "width")
            let h = try size(cab.height, kind.height, id, "height")
            let table = kind.cornerDepths?[String(format: "%g", w)]
            let d = try size(cab.depth, table ?? kind.depth, id, "depth")
            let z0: Double
            switch kind.mount {
            case "wall": z0 = pack.heights.plinth + pack.heights.carcass + pack.heights.worktop + pack.wallGap
            case "stack": z0 = (host?.z0 ?? 0) + (host?.h ?? 0)
            default: z0 = pack.heights.plinth
            }
            let u0 = host?.u0 ?? cursor
            slots.append(Slot(index: n, cab: cab, kind: kind, u0: u0, u1: u0 + w, h: h, d: d, z0: z0))
            if host == nil { cursor += w }
        }
        return slots
    }

    static func overlaps(_ parts: [Part], prefix: String) throws {
        let eps = 0.5
        let owner = parts.map { slot($0.id, prefix: prefix)?.run ?? -1 }
        for i in parts.indices {
            for j in parts.indices where j > i && owner[i] != owner[j] {
                let a = parts[i], b = parts[j]
                if min(a.maxX, b.maxX) - max(a.x, b.x) > eps, min(a.maxY, b.maxY) - max(a.y, b.y) > eps,
                   min(a.maxZ, b.maxZ) - max(a.z, b.z) > eps {
                    throw KitchenError.overlap(a.id, b.id)
                }
            }
        }
    }

    static func make(_ f: String) -> Front? {
        if let type = FrontType(rawValue: f) { return Front(type: type) }
        return Appliance(rawValue: f).map { Front(type: .appliance, appliance: $0) }
    }

    static func leaves(_ slot: Slot, id: String, stack: [Front], pack: KitchenPack) throws -> [Leaf] {
        struct Block { var front: Front; var weights: [Double]; var span: Double? }
        let gap = pack.front.gap
        var blocks: [Block] = []
        for f in stack {
            var weights = [1.0]
            if f.type == .drawers {
                let names = f.drawers ?? pack.drawer.counts[String(f.count ?? 1)] ?? []
                guard !names.isEmpty else { throw KitchenError.split(id, "drawers") }
                weights = try names.map { name in
                    guard let share = pack.drawer.split[name], share > 0 else { throw KitchenError.unknown(id, name) }
                    return share
                }
            }
            var span = f.height
            if span == nil, f.type == .appliance, let a = f.appliance, let own = pack.appliance[a.rawValue], own.height > 0 {
                span = own.height
            }
            if let span, !(span.isFinite && span > 0) { throw KitchenError.size(id, "front height") }
            blocks.append(Block(front: f, weights: weights, span: span))
        }
        let fixed = blocks.compactMap(\.span).reduce(0, +)
        let flex = blocks.filter { $0.span == nil }.count
        guard fixed <= slot.h + 0.5 else { throw KitchenError.split(id, "fronts add up to \(fixed) in a cabinet \(slot.h) high") }
        let share = flex == 0 ? 0 : (slot.h - fixed) / Double(flex)
        guard flex == 0 || share > 0 else { throw KitchenError.split(id, "no height left for the other fronts") }
        var cursor = slot.z0 + slot.h
        var index = 0
        var out: [Leaf] = []
        for block in blocks {
            let span = block.span ?? share
            let usable = span - Double(block.weights.count) * gap
            let total = block.weights.reduce(0, +)
            for weight in block.weights {
                let height = usable * weight / total
                let least = block.front.type == .drawers ? pack.drawer.min : 0
                guard height > least else { throw KitchenError.split(id, "front \(index) is \(height) high") }
                let side = block.front.side ?? (slot.w >= pack.door.pairFrom ? .pair : pack.door.side)
                out.append(Leaf(front: block.front, side: side, height: height, top: cursor - gap / 2, index: index))
                cursor -= height + gap
                index += 1
            }
        }
        return out
    }

    static func emit(_ slots: [Slot], run: Int, joined: Bool, frame f: Frame, spec: KitchenSpec, pack: KitchenPack, prefix: String,
                     wallLine V: Double, into out: inout Kitchen, used: inout Set<String>) throws {
        let ft = pack.front.thickness
        let h = pack.heights
        func tag(_ mount: String) -> String {
            (pack.groups[mount] ?? mount) + (run == 0 ? "" : "_\(run)")
        }
        func box(_ id: String, _ name: String, _ material: String, _ role: String, _ group: String,
                 _ u0: Double, _ u1: Double, _ v0: Double, _ v1: Double, _ z0: Double, _ z1: Double) -> Part {
            used.insert(material)
            let a = f.point(u0, v0), b = f.point(u1, v1)
            return Part(id: prefix + id, name: name, material: material, x: min(a.x, b.x), y: min(a.y, b.y), z: z0,
                        w: abs(a.x - b.x), d: abs(a.y - b.y), h: z1 - z0, role: role, group: group)
        }
        func cm(_ w: Double) -> String { String(Int((w / 10).rounded())) }
        let live = slots.filter { spec.wall || ($0.kind.mount == "floor") }
        for slot in live {
            let id = "r\(run)c\(slot.index)"
            let cab = slot.cab
            let group = tag(slot.kind.mount)
            let vb = V - slot.d, vf = vb - ft
            let z1 = slot.z0 + slot.h
            let carcass = cab.material ?? pack.materials["carcass"] ?? ""
            let frontMaterial = cab.frontMaterial ?? pack.materials["front"] ?? ""
            var stack = cab.fronts ?? (make(slot.kind.front).map { [$0] } ?? [])
            let inlays = stack.filter { $0.type == .appliance && $0.appliance.flatMap { pack.appliance[$0.rawValue]?.inlay } != nil }
            stack.removeAll { front in inlays.contains(front) }
            let hollow = slot.kind.front == "none" && cab.fronts == nil || (!stack.isEmpty && stack.allSatisfy { $0.type == .open })
            let title = (slot.kind.name) + " " + cm(slot.w)
            if hollow {
                let p = pack.panel
                let words = pack.words, role = pack.roles["carcass"] ?? ""
                let w = { (k: String) in words[k] ?? "" }
                out.parts += [
                    box(id + "p0", w("side"), carcass, role, group, slot.u0, slot.u0 + p, vb, V, slot.z0, z1),
                    box(id + "p1", w("side"), carcass, role, group, slot.u1 - p, slot.u1, vb, V, slot.z0, z1),
                    box(id + "p2", w("bottom"), carcass, role, group, slot.u0 + p, slot.u1 - p, vb, V - pack.back, slot.z0, slot.z0 + p),
                    box(id + "p3", w("top"), carcass, role, group, slot.u0 + p, slot.u1 - p, vb, V - pack.back, z1 - p, z1),
                    box(id + "p4", w("back"), carcass, role, group, slot.u0 + p, slot.u1 - p, V - pack.back, V, slot.z0 + p, z1 - p)
                ]
                let shelves = max(0, Int(slot.h / pack.shelf) - 1)
                for k in 0..<shelves {
                    let z = slot.z0 + slot.h * Double(k + 1) / Double(shelves + 1) - p / 2
                    out.parts.append(box(id + "s\(k)", w("shelf"), carcass, role, group, slot.u0 + p, slot.u1 - p, vb, V - pack.back, z, z + p))
                }
            } else {
                out.parts.append(box(id, title, carcass, pack.roles["carcass"] ?? "", group, slot.u0, slot.u1, vb, V, slot.z0, z1))
            }
            for leaf in try leaves(slot, id: id, stack: stack, pack: pack) where leaf.front.type != .open {
                try front(leaf, slot: slot, id: id, material: leaf.front.material ?? frontMaterial, group: group, vf: vf,
                          frame: f, pack: pack, box: box, into: &out)
            }
            for (k, inlay) in inlays.enumerated() {
                guard let a = inlay.appliance, let own = pack.appliance[a.rawValue], let spot = own.inlay else { continue }
                guard spot.w <= slot.w, vf + spot.fromFront + spot.d <= V else { throw KitchenError.fit(id, a.rawValue) }
                let top = z1 + (spec.worktop && slot.kind.worktop == true ? h.worktop : 0)
                let mid = (slot.u0 + slot.u1) / 2
                out.parts.append(box(id + "i\(k)", own.name, own.material, pack.roles["inlay"] ?? "", group, mid - spot.w / 2,
                                     mid + spot.w / 2, vf + spot.fromFront, vf + spot.fromFront + spot.d, top, top + spot.h))
            }
        }
        var worktops = 0, plinths = 0
        var group: [Slot] = []
        func close() {
            defer { group = [] }
            guard let first = group.first, let last = group.last else { return }
            let base = first.index == slots.first?.index
            let end = last.index == slots.last(where: { !$0.stacked })?.index
            let name = tag(first.kind.mount)
            let vf = V - first.d - ft
            if first.kind.worktop == true, spec.worktop {
                let near = base && !joined && !first.corner ? pack.overhang : 0
                let far = end && !last.corner ? pack.overhang : 0
                let front = first.corner ? 0 : pack.overhang
                out.parts.append(box("r\(run)w\(worktops)", pack.words["worktop"] ?? "", pack.materials["worktop"] ?? "",
                                     pack.roles["worktop"] ?? "", name, first.u0 - near, last.u1 + far, vf - front, V,
                                     h.plinth + h.carcass, h.plinth + h.carcass + h.worktop))
                worktops += 1
            }
            if spec.plinth, first.kind.mount == "floor" {
                out.parts.append(box("r\(run)p\(plinths)", pack.words["plinth"] ?? "", pack.materials["plinth"] ?? "",
                                     pack.roles["plinth"] ?? "", name, first.u0, last.u1, vf + pack.plinthSetback, V, 0, h.plinth))
                plinths += 1
            }
        }
        for slot in slots where !slot.stacked && (spec.wall || slot.kind.mount == "floor") {
            if slot.kind.mount != "floor" { close(); continue }
            if let last = group.last, last.d != slot.d || (last.kind.worktop == true) != (slot.kind.worktop == true) { close() }
            group.append(slot)
        }
        close()
    }

    static func front(_ leaf: Leaf, slot: Slot, id: String, material: String, group: String, vf: Double, frame f: Frame,
                      pack: KitchenPack, box: (String, String, String, String, String, Double, Double, Double, Double, Double, Double) -> Part,
                      into out: inout Kitchen) throws {
        let gap = pack.front.gap, ft = pack.front.thickness
        let kind = leaf.front.type
        let own = leaf.front.appliance.flatMap { pack.appliance[$0.rawValue] }
        let role = pack.roles["front"] ?? ""
        let paint = kind == .appliance ? (own?.material ?? material) : (kind == .glass ? (pack.materials["glass"] ?? material) : material)
        let word = kind == .drawers ? "drawer" : (kind == .glass ? "glass" : "door")
        let motion = own?.motion ?? (kind == .drawers ? "slide" : "door")
        let lo = leaf.top - leaf.height
        let mid = leaf.index
        func leafBox(_ suffix: String, _ u0: Double, _ u1: Double, _ name: String) -> Part {
            box(id + "f\(mid)" + suffix, name, paint, role, group, u0, u1, vf, vf + ft, lo, leaf.top)
        }
        func unit(_ suffix: String, _ type: UnitKind, _ motion: Motion) {
            out.units.append(Unit(id: id + "u\(mid)" + suffix, kind: type, front: [id + "f\(mid)" + suffix], motion: motion))
        }
        func hinged(_ suffix: String, _ edge: Double, _ side: HingeSide) {
            let p = f.point(edge, vf)
            let angle = side == .left ? -pack.door.angle : pack.door.angle
            unit(suffix, .door, .hinge(pivot: Point3(x: p.x, y: p.y, z: lo), axis: .z, degrees: angle))
        }
        let name = own?.name ?? pack.words[word] ?? ""
        let u0 = slot.u0 + gap / 2, u1 = slot.u1 - gap / 2
        if kind == .drawers {
            out.parts.append(leafBox("", u0, u1, name))
            let travel = slot.d - pack.drawer.reserve
            guard travel > 0 else { throw KitchenError.fit(id, "drawer") }
            unit("", .drawer, .slide(dx: f.s * travel, dy: -f.c * travel, dz: 0))
            return
        }
        if motion == "flap" {
            out.parts.append(leafBox("", u0, u1, own?.name ?? pack.words["flap"] ?? name))
            let p = f.point((u0 + u1) / 2, vf)
            let axis: TurnAxis = f.c != 0 ? .x : .y
            let sign = f.c != 0 ? f.c : f.s
            unit("", .flap, .hinge(pivot: Point3(x: p.x, y: p.y, z: lo), axis: axis, degrees: pack.door.flap * sign))
            return
        }
        let swing = motion == "none" ? false : true
        if leaf.side == .pair {
            let leafW = (slot.w - 2 * gap) / 2
            let parts = [("a", u0, u0 + leafW, HingeSide.left), ("b", u1 - leafW, u1, HingeSide.right)]
            for (suffix, a, b, hinge) in parts {
                out.parts.append(leafBox(suffix, a, b, name))
                if swing { hinged(suffix, hinge == .left ? a : b, hinge) }
            }
        } else {
            out.parts.append(leafBox("", u0, u1, name))
            if swing { hinged("", leaf.side == .left ? u0 : u1, leaf.side) }
        }
    }
}
