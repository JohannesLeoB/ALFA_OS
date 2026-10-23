import Assist
import CoreGraphics
import DrawingKit
import DrawsRender
import Foundation

public enum Words {
    public static func message(_ error: Error) -> String {
        switch error {
        case let e as Refusal: return e.message
        case let e as DrawingError: return describe(e)
        case let e as DecodingError: return describe(e)
        case let e as KitchenError: return describe(e)
        default: return "\(error)"
        }
    }

    static func describe(_ error: DrawingError) -> String {
        switch error {
        case .empty: return "no parts"
        case .duplicateID(let id): return "id \(id) is used twice"
        case .invalidPart(let id): return "part \(id): sizes must be above zero and ids must exist"
        case .tooLarge(let id): return "\(id): a value is beyond 100000"
        case .unsupportedView(let name): return "view \(name) is not supported"
        case .invalidCamera: return "camera values are invalid"
        case .overflow: return "the views do not fit the sheet"
        case .pack(let list): return "pack: " + list.joined(separator: ", ")
        case .sharedPart(let id): return "part \(id) belongs to two units"
        case .invalidUnit(let id): return "unit \(id): needs a front, a sound motion, known ids and amounts from 0 to 1"
        }
    }

    static func describe(_ error: KitchenError) -> String {
        switch error {
        case .empty: return "kitchen: runs and every run need cabinets"
        case .turn(let n): return "kitchen: turn \(n) is not 0, 90, 180 or 270, or does not fit the corner it joins"
        case .join(let i): return "kitchen: run \(i) has no origin, so the run before it must end with a corner cabinet"
        case .size(let id, let field): return "\(id): \(field) must be above zero"
        case .host(let id): return "\(id): a top cabinet needs a tall or housing cabinet right before it"
        case .unknown(let id, let name): return "\(id): unknown \(name)"
        case .split(let id, let why): return "\(id): the fronts do not fit, \(why)"
        case .fit(let id, let what): return "\(id): \(what) does not fit into the cabinet"
        case .overlap(let a, let b): return "kitchen: \(a) and \(b) overlap; move a run or change its origin"
        case .edit(let id, let why): return "\(id): \(why)"
        }
    }

    static func describe(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, _): return "missing field \(key.stringValue)"
        case .typeMismatch(_, let context), .valueNotFound(_, let context):
            return "wrong type at " + context.codingPath.map(\.stringValue).joined(separator: ".")
        default: return "invalid value"
        }
    }

    static func cell(_ c: Cell) -> JSON {
        [
            "id": .string(c.id), "view": .string(c.view.rawValue), "x": .num(c.frame.minX), "y": .num(c.frame.minY),
            "w": .num(c.frame.width), "h": .num(c.frame.height), "scale": c.scale.map(JSON.num) ?? .null,
            "focus": c.focus.map(JSON.string) ?? .null, "step": .num(Double(c.step)), "dims": .bool(c.dims)
        ]
    }
}

struct CellWire: Decodable {
    var id: String
    var view: ViewKind
    var x: Double
    var y: Double
    var w: Double
    var h: Double
    var scale: Double?
    var focus: String?
    var step: Int?
    var dims: Bool?

    var cell: Cell {
        Cell(id: id, view: view, frame: CGRect(x: x, y: y, width: w, height: h), scale: scale, focus: focus,
             step: step ?? 0, dims: dims ?? (view != .iso && view != .perspective))
    }
}

extension Draft {
    func part(_ fields: [String: JSON]) throws -> Part {
        var next = fields
        if next["name"] == nil { next["name"] = next["id"] }
        do {
            return try JSON.object(next).decode(Part.self)
        } catch {
            throw Refusal("part \(fields["id"]?.string ?? "?"): " + Words.message(error))
        }
    }

    mutating func addParts(_ input: JSON) throws -> String {
        guard let list = input["parts"]?.array, !list.isEmpty else { throw Refusal("parts: a non-empty list is required") }
        for item in list { parts.append(try part(item.object ?? [:])) }
        return "added \(list.count), parts now \(parts.count)"
    }

    mutating func addKitchen(_ input: JSON, pack: KitchenPack?) throws -> String {
        guard let pack else { throw Refusal("add_kitchen: the cabinet pack is not loaded") }
        let spec: KitchenSpec
        do {
            spec = try input.decode(KitchenSpec.self)
        } catch {
            throw Refusal("add_kitchen: " + Words.message(error))
        }
        return try build(spec, pack: pack)
    }

    mutating func editCabinet(_ input: JSON, pack: KitchenPack?) throws -> String {
        guard let pack else { throw Refusal("edit_cabinet: the cabinet pack is not loaded") }
        guard var spec = kitchen else { throw Refusal("edit_cabinet: build a kitchen with add_kitchen first") }
        guard let op = input["op"]?.string else { throw Refusal("edit_cabinet: op is required") }
        let prefix = spec.prefix ?? ""
        var names = (input["ids"]?.array ?? []).compactMap(\.string)
        if let one = input["id"]?.string { names.append(one) }
        var spots: [Locus] = []
        for name in names {
            guard let spot = Locus(id: name, prefix: prefix) else { throw Refusal("edit_cabinet: \(name) is not a cabinet id") }
            spots.append(spot)
        }
        let number = { (key: String) in input[key]?.number }
        let text = { (key: String) in input[key]?.string }
        let kind = text("kind").flatMap(CabinetKind.init(rawValue:))
        let growing = ["insert", "duplicate", "remove"].contains(op)
        let order = growing ? spots.sorted { ($0.run, $0.item) > ($1.run, $1.item) } : spots
        if op == "override", input["shared"]?.bool == true {
            guard let field = text("field").flatMap(Field.init(rawValue:)), let setting = Setting.make(field, text("value") ?? "") else {
                throw Refusal("edit_cabinet: override needs a valid field and value")
            }
            spec = try spec.sharing(setting)
        } else {
            guard !order.isEmpty else { throw Refusal("edit_cabinet: id or ids is required") }
            for spot in order {
                do {
                    switch op {
                    case "resize":
                        guard let axis = text("axis").flatMap(Extent.init(rawValue:)), let delta = number("delta") else { throw Refusal("resize needs axis and delta") }
                        spec = try spec.resize(spot, axis, by: delta, pack: pack)
                    case "set": spec = try spec.set(spot, width: number("width"), height: number("height"), depth: number("depth"))
                    case "insert":
                        guard let kind else { throw Refusal("insert needs kind") }
                        spec = try spec.insert(kind, at: spot, text("side") == "before" ? .before : .after)
                    case "duplicate": spec = try spec.duplicate(spot)
                    case "remove": spec = try spec.remove(spot)
                    case "move": spec = try spec.move(spot, text("step") == "left" ? .left : .right)
                    case "flip": spec = try spec.flipHinge(spot, pack: pack)
                    case "split":
                        guard let split = text("split").flatMap(Split.init(name:)) else { throw Refusal("split is not known") }
                        spec = try spec.setSplit(spot, split, pack: pack)
                    case "type":
                        guard let kind else { throw Refusal("type needs kind") }
                        spec = try spec.setType(spot, kind, pack: pack)
                    case "override":
                        guard let field = text("field").flatMap(Field.init(rawValue:)), let setting = Setting.make(field, text("value") ?? "") else {
                            throw Refusal("override needs a valid field and value")
                        }
                        spec = try spec.overriding(spot, setting)
                    case "reset": spec = try spec.resetToShared(spot, text("field").flatMap(Field.init(rawValue:)))
                    default: throw Refusal("op \(op) is not known")
                    }
                } catch let refusal as Refusal {
                    throw Refusal("edit_cabinet: " + refusal.message)
                }
            }
        }
        return try build(spec, pack: pack)
    }

    @discardableResult
    public mutating func build(_ spec: KitchenSpec, pack: KitchenPack) throws -> String {
        let made = try Kitchen.generate(spec, pack: pack)
        let prefix = spec.prefix ?? ""
        let gone = Set(parts.map(\.id).filter { Kitchen.owns($0, prefix: prefix) })
        parts.removeAll { gone.contains($0.id) }
        let dropped = Set(units.map(\.id).filter { Kitchen.owns($0, prefix: prefix) })
        units.removeAll { dropped.contains($0.id) }
        pose = pose.filter { entry in !dropped.contains(entry.key) || made.units.contains { $0.id == entry.key } }
        if let a = accent, gone.contains(a), !made.parts.contains(where: { $0.id == a }) { accent = nil }
        parts += made.parts
        units += made.units
        kitchen = spec
        return "kitchen: \(made.parts.count) parts, \(made.units.count) units; runs "
            + made.runs.map { "r\($0.run) \(String(format: "%g", $0.length)) mm, \($0.cabinets) cabinets" }.joined(separator: "; ")
            + "; materials " + made.materials.joined(separator: ", ")
    }

    mutating func updatePart(_ input: JSON) throws -> String {
        guard let id = input["id"]?.string, let index = parts.firstIndex(where: { $0.id == id }) else {
            throw Refusal("update_part: unknown part id")
        }
        var fields = try JSON(encoding: parts[index]).object ?? [:]
        for (key, value) in input.object ?? [:] where key != "id" { fields[key] = value }
        parts[index] = try part(fields)
        return "updated \(id)"
    }

    mutating func removePart(_ input: JSON) throws -> String {
        if let unit = input["unit"]?.string {
            guard units.contains(where: { $0.id == unit }) else { throw Refusal("remove_part: unknown unit id") }
            units.removeAll { $0.id == unit }
            pose[unit] = nil
            return "removed unit \(unit)"
        }
        guard let id = input["id"]?.string, parts.contains(where: { $0.id == id }) else {
            throw Refusal("remove_part: unknown part id")
        }
        parts.removeAll { $0.id == id }
        units = units.compactMap { unit in
            var next = unit
            next.front.removeAll { $0 == id }
            next.body.removeAll { $0 == id }
            return next.front.isEmpty ? nil : next
        }
        pose = pose.filter { entry in units.contains { $0.id == entry.key } }
        cells = cells.map { cell in
            var next = cell
            if next.focus == id { next.focus = nil }
            return next
        }
        if accent == id { accent = nil }
        return "removed \(id), parts now \(parts.count)"
    }

    mutating func addUnit(_ input: JSON) throws -> String {
        guard let id = input["id"]?.string else { throw Refusal("add_unit: id is required") }
        let fields: [String: JSON] = [
            "id": .string(id), "kind": input["kind"] ?? .null, "front": input["fronts"] ?? [],
            "body": input["body"] ?? [], "motion": input["motion"] ?? .null
        ]
        let unit: DrawingKit.Unit
        do {
            unit = try JSON.object(fields).decode(DrawingKit.Unit.self)
        } catch {
            throw Refusal("unit \(id): " + Words.message(error))
        }
        if let index = units.firstIndex(where: { $0.id == id }) { units[index] = unit } else { units.append(unit) }
        return "unit \(id) set, units now \(units.count)"
    }

    mutating func setPose(_ input: JSON) throws -> String {
        guard let amounts = input["amounts"]?.object else { throw Refusal("set_pose: amounts is required") }
        let values = amounts.compactMapValues(\.number)
        guard values.count == amounts.count else { throw Refusal("set_pose: amounts must be numbers") }
        try Validate.pose(values, units: units)
        pose.merge(values) { _, new in new }
        return "pose set for \(values.count) units"
    }

    func within(_ value: Double?, _ range: ClosedRange<Double>, _ name: String) throws -> Double? {
        guard let value else { return nil }
        guard value.isFinite, range.contains(value) else {
            throw Refusal("\(name) must be between \(range.lowerBound) and \(range.upperBound)")
        }
        return value
    }

    mutating func setCamera(_ input: JSON, _ bench: Bench) throws -> String {
        let az = try within(input["azimuth"]?.number, bench.dials.azimuth, "azimuth")
        let el = try within(input["elevation"]?.number, bench.dials.elevation, "elevation")
        if let az { azimuth = az }
        if let el { elevation = el }
        switch input["kind"]?.string {
        case "iso": cells = cells.map { $0.view == .perspective ? $0.with(.iso) : $0 }
        case "perspective": cells = cells.map { $0.view == .iso ? $0.with(.perspective) : $0 }
        case "preset":
            azimuth = ViewSpec(kind: .iso).azimuth
            elevation = ViewSpec.isoElevation
        case nil: break
        default: throw Refusal("kind must be iso, perspective or preset")
        }
        return "camera azimuth \(azimuth) elevation \(elevation)"
    }

    mutating func setStyle(_ input: JSON, _ bench: Bench) throws -> String {
        if let tones = input["faces"]?.array?.compactMap(\.string), input["faces"]?.array?.count == tones.count {
            guard tones.count == 3, tones.allSatisfy(Self.isColor) else { throw Refusal("faces: three colours as # and six hex digits") }
            faces = tones
            tone = true
        }
        if let fill = input["fill"]?.string {
            guard fill == "tone" || fill == "material" else { throw Refusal("fill must be tone or material") }
            tone = fill == "tone"
        }
        edge = try within(input["edge"]?.number, bench.dials.edge, "edge") ?? edge
        outline = try within(input["outline"]?.number, bench.dials.outline, "outline") ?? outline
        shadow = try within(input["shadow"]?.number, bench.dials.shadow, "shadow") ?? shadow
        if let id = input["accent"]?.string {
            guard id.isEmpty || parts.contains(where: { $0.id == id }) else { throw Refusal("accent: unknown part id") }
            accent = id.isEmpty ? nil : id
        }
        if let color = input["accent_color"]?.string {
            guard color.isEmpty || Self.isColor(color) else { throw Refusal("accent_color: # and six hex digits") }
            accentColor = color.isEmpty ? nil : color
        }
        if let on = input["dimensions"]?.bool { dimensions = on }
        return "style set"
    }

    mutating func setTexture(_ input: JSON, images: Set<String>, codes: Set<String>) throws -> String {
        guard let code = input["material"]?.string, codes.contains(code) else {
            throw Refusal("set_texture: material must be one of " + codes.sorted().joined(separator: ", "))
        }
        guard let name = input["image"]?.string else { throw Refusal("set_texture: image is required") }
        if name.isEmpty {
            look.textures[code] = nil
            return "texture removed for \(code)"
        }
        guard images.contains(name) else { throw Refusal("set_texture: image must be one of " + images.sorted().joined(separator: ", ")) }
        var texture = look.textures[code] ?? Texture(image: name)
        texture.image = name
        if let normal = input["normal"]?.string {
            guard normal.isEmpty || images.contains(normal) else { throw Refusal("set_texture: normal must be an image name") }
            texture.normal = normal.isEmpty ? nil : normal
        }
        texture.tile = try within(input["tile_mm"]?.number, 20...5000, "tile_mm") ?? texture.tile
        texture.roughness = try within(input["roughness"]?.number, 0...1, "roughness") ?? texture.roughness
        look.textures[code] = texture
        return "texture set for \(code): \(name), tile \(texture.tile) mm, roughness \(texture.roughness)"
    }

    mutating func setLight(_ input: JSON) throws -> String {
        var next = look.light
        if let name = input["preset"]?.string {
            guard let preset = LightPreset(rawValue: name) else {
                throw Refusal("preset must be one of " + LightPreset.allCases.map(\.rawValue).joined(separator: ", "))
            }
            next = LightSpec(preset: preset)
        }
        next.azimuth = try within(input["azimuth"]?.number, 0...360, "azimuth") ?? next.azimuth
        next.elevation = try within(input["elevation"]?.number, 5...85, "elevation") ?? next.elevation
        look.light = next
        return "light \(next.preset.rawValue)"
    }

    mutating func setLayout(_ input: JSON, _ bench: Bench) throws -> String {
        guard let kind = input["kind"]?.string, bench.kinds.contains(kind) else {
            throw Refusal("kind must be one of " + bench.kinds.joined(separator: ", "))
        }
        var next: [Cell]
        if let list = input["cells"]?.array {
            do {
                next = try list.map { try $0.decode(CellWire.self).cell }
            } catch {
                throw Refusal("cells: " + Words.message(error))
            }
            try validate(next, bench)
        } else {
            next = bench.preset(kind, parts)
        }
        layout = kind
        cells = next
        return "layout \(kind), cells \(next.count)"
    }

    func validate(_ list: [Cell], _ bench: Bench) throws {
        var seen = Set<String>()
        for cell in list {
            guard seen.insert(cell.id).inserted else { throw Refusal("cells: id \(cell.id) is used twice") }
            let f = cell.frame
            guard [f.minX, f.minY, f.width, f.height].allSatisfy(\.isFinite), f.width > 0, f.height > 0,
                  f.minX >= 0, f.minY >= 0, f.maxX <= bench.template.width, f.maxY <= bench.template.height else {
                throw Refusal("cells: \(cell.id) lies outside the sheet or has no size")
            }
            if let focus = cell.focus, !parts.contains(where: { $0.id == focus }) { throw Refusal("cells: \(cell.id) focus is unknown") }
            if let scale = cell.scale, !(scale.isFinite && scale > 0) { throw Refusal("cells: \(cell.id) scale must be above zero") }
        }
    }
}

extension Cell {
    func with(_ next: ViewKind) -> Cell {
        var out = self
        out.view = next
        return out
    }
}
