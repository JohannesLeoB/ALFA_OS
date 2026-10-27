import Foundation

enum EquipmentDensity: String, Equatable, Sendable, CaseIterable {
    case none
    case low
    case medium
    case high
    case veryHigh = "very_high"
    case unknown

    init(rawCorpus: String) {
        let key = rawCorpus.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch key {
        case "none": self = .none
        case "low": self = .low
        case "medium": self = .medium
        case "high": self = .high
        case "very_high", "veryhigh": self = .veryHigh
        default: self = .unknown
        }
    }

    var level: Int? {
        switch self {
        case .none: 0
        case .low: 1
        case .medium: 2
        case .high: 3
        case .veryHigh: 4
        case .unknown: nil
        }
    }

    static func classify(drawersPerLfm value: Double?) -> EquipmentDensity {
        guard let value, value >= 0 else { return .unknown }
        if value == 0 { return .none }
        if value <= 1.5 { return .low }
        if value <= 3.0 { return .medium }
        if value <= 4.5 { return .high }
        return .veryHigh
    }

    static func classifyQuery(drawerCount: Int, lengthM: Double?) -> EquipmentDensity {
        guard drawerCount > 0, let lengthM, lengthM > 0 else { return .unknown }
        return classify(drawersPerLfm: Double(drawerCount) / lengthM)
    }

    func isHardIncompatible(with other: EquipmentDensity) -> Bool {
        guard let selfLevel = level, let otherLevel = other.level else { return false }
        return abs(selfLevel - otherLevel) >= 2
    }
}
