import Foundation
import AlfaKit

public enum ClickUpProjectPhase: Int, CaseIterable, Sendable, Equatable {
    case briefing = 0
    case angebot = 1
    case planung = 2
    case order = 3
    case ausfuehrung = 4
    case abschluss = 5
    case service = 6

    public var label: String {
        switch self {
        case .briefing:   "Briefing"
        case .angebot:    "Angebot"
        case .planung:    "Planung"
        case .order: "Bestellung"
        case .ausfuehrung: "Ausführung"
        case .abschluss:  "Abschluss"
        case .service:    "Service"
        }
    }

    public var mykilosStage: ProjectLifecycleStage {
        switch self {
        case .briefing:    .briefing
        case .angebot:     .angebot
        case .planung:     .planung
        case .order:  .order
        case .ausfuehrung: .ausfuehrung
        case .abschluss:   .abschluss
        case .service:     .service
        }
    }

    public static func clickUpPhase(for mykilosStage: ProjectLifecycleStage) -> ClickUpProjectPhase {
        switch mykilosStage {
        case .briefing:    .briefing
        case .angebot:     .angebot
        case .planung:     .planung
        case .order:  .order
        case .ausfuehrung: .ausfuehrung
        case .abschluss:   .abschluss
        case .service:     .service
        }
    }

    public static let syncStatusFeldName = "mykilOS-Sync"
}
