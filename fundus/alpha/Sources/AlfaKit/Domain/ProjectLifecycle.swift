import Foundation

public enum ProjectLifecycleStage: Int, CaseIterable, Codable, Sendable, Identifiable {
    case briefing = 0
    case angebot
    case planung
    case order
    case ausfuehrung
    case abschluss
    case service

    public var id: Int { rawValue }

    public var label: String {
        switch self {
        case .briefing:    "Briefing"
        case .angebot:     "Angebot"
        case .planung:     "Planung"
        case .order:  "Bestellung"
        case .ausfuehrung: "Ausführung"
        case .abschluss:   "Abschluss"
        case .service:     "Service"
        }
    }
}

public enum ProjectLifecycleDeriver {
    public static func derive(timeBookedHours: Double, isArchived: Bool) -> ProjectLifecycleStage {
        if isArchived { return .abschluss }
        if timeBookedHours > 0 { return .planung }
        return .briefing
    }
}
