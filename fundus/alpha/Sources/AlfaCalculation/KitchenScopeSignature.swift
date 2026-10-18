import Foundation

public enum KitchenEquipmentDensity: String, Codable, Equatable, Sendable, CaseIterable {
    case none
    case low
    case medium
    case high
    case veryHigh = "very_high"
    case unknown

    public init(rawCorpus: String) {
        let key = rawCorpus.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch key {
        case "none":               self = .none
        case "low":                self = .low
        case "medium":             self = .medium
        case "high":               self = .high
        case "very_high", "veryhigh": self = .veryHigh
        default:                   self = .unknown
        }
    }

    public var level: Int? {
        switch self {
        case .none:     return 0
        case .low:      return 1
        case .medium:   return 2
        case .high:     return 3
        case .veryHigh: return 4
        case .unknown:  return nil
        }
    }

    public static func classify(drawersPerLfm value: Double?) -> KitchenEquipmentDensity {
        guard let value, value >= 0 else { return .unknown }
        if value == 0 { return .none }
        if value <= 1.5 { return .low }
        if value <= 3.0 { return .medium }
        if value <= 4.5 { return .high }
        return .veryHigh
    }

    public static func classify(drawerCount: Int, lengthM: Double?) -> KitchenEquipmentDensity {
        guard let lengthM, lengthM > 0 else { return .unknown }
        return classify(drawersPerLfm: Double(drawerCount) / lengthM)
    }

    public static func classifyQuery(drawerCount: Int, lengthM: Double?) -> KitchenEquipmentDensity {
        guard drawerCount > 0, let lengthM, lengthM > 0 else { return .unknown }
        return classify(drawersPerLfm: Double(drawerCount) / lengthM)
    }

    public func isHardIncompatible(with other: KitchenEquipmentDensity) -> Bool {
        guard let selfLevel = level, let otherLevel = other.level else { return false }
        return abs(selfLevel - otherLevel) >= 2
    }
}

public struct KitchenScopeSignature: Equatable, Codable, Sendable {
    public let equipmentDensity: KitchenEquipmentDensity
    public let drawerCount: Int
    public let lengthM: Double?

    public init(equipmentDensity: KitchenEquipmentDensity, drawerCount: Int, lengthM: Double?) {
        self.equipmentDensity = equipmentDensity
        self.drawerCount = drawerCount
        self.lengthM = lengthM
    }

    public static func fromQuery(drawerCount: Int, lengthM: Double?) -> KitchenScopeSignature {
        KitchenScopeSignature(
            equipmentDensity: .classifyQuery(drawerCount: drawerCount, lengthM: lengthM),
            drawerCount: drawerCount,
            lengthM: lengthM
        )
    }
}
