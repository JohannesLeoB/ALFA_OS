import Foundation

public enum GripStyle: String, Codable, CaseIterable, Sendable { case handle, channel, push }

public enum FrontStyle: String, Codable, CaseIterable, Sendable { case flat, frame, glass }

public enum PlinthStyle: String, Codable, CaseIterable, Sendable { case panel, legs }

public struct Features: Codable, Hashable, Sendable {
    public var grip: GripStyle?
    public var style: FrontStyle?
    public var plinth: PlinthStyle?
    public var edge: Bool?

    public init(grip: GripStyle? = nil, style: FrontStyle? = nil, plinth: PlinthStyle? = nil, edge: Bool? = nil) {
        self.grip = grip; self.style = style; self.plinth = plinth; self.edge = edge
    }

    public var isEmpty: Bool { self == Features() }
}

public struct Materials: Codable, Hashable, Sendable {
    public var front: String?
    public var carcass: String?
    public var worktop: String?
    public var plinth: String?

    public init(front: String? = nil, carcass: String? = nil, worktop: String? = nil, plinth: String? = nil) {
        self.front = front; self.carcass = carcass; self.worktop = worktop; self.plinth = plinth
    }

    public var isEmpty: Bool { self == Materials() }
}

public struct Resolved: Equatable, Sendable {
    public var grip: GripStyle
    public var style: FrontStyle
    public var plinth: PlinthStyle
    public var edge: Bool
    public var front: String
    public var carcass: String
    public var worktop: String
    public var plinthMaterial: String
}

public extension KitchenSpec {
    func resolve(_ cab: Cabinet, pack: KitchenPack) -> Resolved {
        let start = pack.start ?? .standard
        return Resolved(
            grip: cab.features?.grip ?? features?.grip ?? start.grip,
            style: cab.features?.style ?? features?.style ?? start.style,
            plinth: cab.features?.plinth ?? features?.plinth ?? start.plinth,
            edge: cab.features?.edge ?? features?.edge ?? start.edge,
            front: cab.materials?.front ?? cab.frontMaterial ?? materials?.front ?? pack.materials["front"] ?? "",
            carcass: cab.materials?.carcass ?? cab.material ?? materials?.carcass ?? pack.materials["carcass"] ?? "",
            worktop: cab.materials?.worktop ?? materials?.worktop ?? pack.materials["worktop"] ?? "",
            plinthMaterial: cab.materials?.plinth ?? materials?.plinth ?? pack.materials["plinth"] ?? "")
    }
}
