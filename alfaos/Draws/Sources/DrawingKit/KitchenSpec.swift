import Foundation

public struct KitchenPoint: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

public enum CabinetKind: String, Codable, CaseIterable, Sendable {
    case base, wall, tall, top, cornerBase, cornerWall, open, housing
}

public enum FrontType: String, Codable, CaseIterable, Sendable { case door, drawers, appliance, open, glass }

public enum HingeSide: String, Codable, Sendable { case left, right, pair }

public enum Appliance: String, Codable, CaseIterable, Sendable { case oven, dishwasher, fridge, hob, sink }

public struct Front: Codable, Hashable, Sendable {
    public var type: FrontType
    public var side: HingeSide?
    public var drawers: [String]?
    public var count: Int?
    public var appliance: Appliance?
    public var height: Double?
    public var material: String?

    public init(type: FrontType, side: HingeSide? = nil, drawers: [String]? = nil, count: Int? = nil,
                appliance: Appliance? = nil, height: Double? = nil, material: String? = nil) {
        self.type = type; self.side = side; self.drawers = drawers; self.count = count
        self.appliance = appliance; self.height = height; self.material = material
    }
}

public struct Cabinet: Codable, Hashable, Sendable {
    public var kind: CabinetKind
    public var width: Double?
    public var height: Double?
    public var depth: Double?
    public var fronts: [Front]?
    public var material: String?
    public var frontMaterial: String?
    public var name: String?
    public var features: Features?
    public var materials: Materials?

    public init(kind: CabinetKind, width: Double? = nil, height: Double? = nil, depth: Double? = nil, fronts: [Front]? = nil,
                material: String? = nil, frontMaterial: String? = nil, name: String? = nil,
                features: Features? = nil, materials: Materials? = nil) {
        self.kind = kind; self.width = width; self.height = height; self.depth = depth; self.fronts = fronts
        self.material = material; self.frontMaterial = frontMaterial; self.name = name
        self.features = features; self.materials = materials
    }
}

public struct KitchenRun: Codable, Hashable, Sendable {
    public var origin: KitchenPoint?
    public var turn: Int?
    public var items: [Cabinet]

    public init(origin: KitchenPoint? = nil, turn: Int? = nil, items: [Cabinet]) {
        self.origin = origin; self.turn = turn; self.items = items
    }
}

public struct KitchenSpec: Codable, Hashable, Sendable {
    public var runs: [KitchenRun]
    public var island: KitchenRun?
    public var worktop: Bool
    public var plinth: Bool
    public var wall: Bool
    public var prefix: String?
    public var features: Features?
    public var materials: Materials?

    public init(runs: [KitchenRun], island: KitchenRun? = nil, worktop: Bool = true, plinth: Bool = true, wall: Bool = true,
                prefix: String? = nil, features: Features? = nil, materials: Materials? = nil) {
        self.runs = runs; self.island = island; self.worktop = worktop; self.plinth = plinth; self.wall = wall
        self.prefix = prefix; self.features = features; self.materials = materials
    }

    enum CodingKeys: String, CodingKey { case runs, island, worktop, plinth, wall, prefix, features, materials }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(runs: try c.decode([KitchenRun].self, forKey: .runs),
                  island: try c.decodeIfPresent(KitchenRun.self, forKey: .island),
                  worktop: try c.decodeIfPresent(Bool.self, forKey: .worktop) ?? true,
                  plinth: try c.decodeIfPresent(Bool.self, forKey: .plinth) ?? true,
                  wall: try c.decodeIfPresent(Bool.self, forKey: .wall) ?? true,
                  prefix: try c.decodeIfPresent(String.self, forKey: .prefix),
                  features: try c.decodeIfPresent(Features.self, forKey: .features),
                  materials: try c.decodeIfPresent(Materials.self, forKey: .materials))
    }

    public var all: [KitchenRun] { runs + (island.map { [$0] } ?? []) }

    public func with(run: Int, item: Int, _ edit: (inout Cabinet) -> Void) -> KitchenSpec {
        var next = self
        if run < runs.count {
            guard next.runs[run].items.indices.contains(item) else { return self }
            edit(&next.runs[run].items[item])
        } else if var isle = next.island, isle.items.indices.contains(item) {
            edit(&isle.items[item])
            next.island = isle
        }
        return next
    }
}

public enum KitchenError: Error, Equatable, Sendable {
    case empty
    case turn(Int)
    case join(Int)
    case size(String, String)
    case host(String)
    case unknown(String, String)
    case split(String, String)
    case fit(String, String)
    case overlap(String, String)
    case edit(String, String)
}

public struct KitchenPack: Codable, Sendable, Equatable {
    public struct Heights: Codable, Sendable, Equatable { public var plinth: Double, carcass: Double, worktop: Double }
    public struct FrontPack: Codable, Sendable, Equatable { public var thickness: Double, gap: Double }
    public struct DoorPack: Codable, Sendable, Equatable {
        public var pairFrom: Double, angle: Double, flap: Double, side: HingeSide
    }
    public struct DrawerPack: Codable, Sendable, Equatable {
        public var split: [String: Double], counts: [String: [String]], min: Double, reserve: Double
    }
    public struct KindPack: Codable, Sendable, Equatable {
        public var mount: String
        public var worktop: Bool?
        public var carries: Bool?
        public var widths: [Double], heights: [Double], depths: [Double]
        public var width: Double, height: Double, depth: Double
        public var name: String
        public var front: String
        public var cornerDepths: [String: Double]?
    }
    public struct StartPack: Codable, Sendable, Equatable {
        public var grip: GripStyle, style: FrontStyle, plinth: PlinthStyle, edge: Bool
        public var handleLength: Double, handleWidth: Double, handleReach: Double, handleInset: Double
        public var channel: Double, rail: Double, railReach: Double, leg: Double, legInset: Double, edgeWidth: Double
        public static let standard = StartPack(grip: .push, style: .flat, plinth: .panel, edge: false, handleLength: 128,
                                               handleWidth: 12, handleReach: 20, handleInset: 40, channel: 20, rail: 50,
                                               railReach: 4, leg: 40, legInset: 30, edgeWidth: 4)
    }
    public struct Inlay: Codable, Sendable, Equatable { public var w: Double, d: Double, h: Double, fromFront: Double }
    public struct AppliancePack: Codable, Sendable, Equatable {
        public var name: String, material: String, height: Double, motion: String
        public var inlay: Inlay?
    }

    public var heights: Heights
    public var front: FrontPack
    public var panel: Double
    public var back: Double
    public var shelf: Double
    public var overhang: Double
    public var wallGap: Double
    public var plinthSetback: Double
    public var door: DoorPack
    public var drawer: DrawerPack
    public var kinds: [String: KindPack]
    public var appliance: [String: AppliancePack]
    public var materials: [String: String]
    public var words: [String: String]
    public var roles: [String: String]
    public var groups: [String: String]
    public var tints: [String: String]
    public var start: StartPack?

    public static func decode(_ data: Data) throws -> KitchenPack { try JSONDecoder().decode(KitchenPack.self, from: data) }

    public static func load(_ url: URL) throws -> KitchenPack { try decode(Data(contentsOf: url)) }
}
