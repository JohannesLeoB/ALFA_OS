enum FrontExecution: String, CaseIterable, Sendable {
    case melamine = "melamin"
    case linoleum
    case veneer = "furnier"
    case lacquer = "lack"
    case stainless = "edelstahl"
    case solidWood = "massivholz"
    case glass = "glas"
    case unknown = "unbekannt"

    var variableMultiplier: Double {
        switch self {
        case .melamine: 0.85
        case .linoleum: 1.00
        case .veneer: 1.05
        case .glass: 1.25
        case .solidWood: 1.30
        case .lacquer: 1.05
        case .stainless: 1.45
        case .unknown: 1.00
        }
    }

    var isThinPrior: Bool {
        switch self {
        case .stainless, .lacquer, .glass, .solidWood: true
        default: false
        }
    }

    var localizationKey: String { "calc.front.\(rawValue)" }

    static func infer(from materials: Set<String>) -> FrontExecution {
        let lowered = Set(materials.map { $0.lowercased() })
        func any(_ needles: String...) -> Bool { needles.contains { needle in lowered.contains { $0.contains(needle) } } }
        if any("edelstahl", "stainless", "v2a", "1.4301") { return .stainless }
        if any("linoleum", "valchromat", "forbo", "forescolor", "fenix") { return .linoleum }
        if any("lack", "hochglanz", "lackiert") { return .lacquer }
        if any("furnier", "eiche", "nussbaum", "esche", "ahorn", "walnuss") { return .veneer }
        if any("massivholz", "massiv") { return .solidWood }
        if any("glas", "riffelglas", "bronzeglas") { return .glass }
        if any("dekorspan", "melamin", "egger", "spanplatte", "pfleiderer", "mdf") { return .melamine }
        return .unknown
    }
}
