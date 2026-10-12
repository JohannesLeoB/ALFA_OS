import Foundation

public enum WidgetBereich: String, CaseIterable, Sendable {
    case tag
    case akte
    case handel
    case workshop

    public var title: String {
        switch self {
        case .tag:       "TAG"
        case .akte:      "AKTE"
        case .handel:    "HANDEL"
        case .workshop: "WERKSTATT"
        }
    }

    public var subtitle: String {
        switch self {
        case .tag:       "Was heute ansteht"
        case .akte:      "Was am Projekt hängt"
        case .handel:    "Was Geld bewegt"
        case .workshop: "Werkzeug zum Anfassen"
        }
    }
}

public extension WidgetKind {
    var area: WidgetBereich {
        switch self {
        case .heuteAnstehend, .calendar, .teamkalender, .tasks, .clickUpAlle,
             .clockodo, .focus, .imFluss, .happaHappa:
            .tag
        case .projectFaves, .drive, .notes, .recentActivity, .aufmass,
             .atelier, .plan, .kreativCanvas, .maps, .heroBild, .phasenfluss:
            .akte
        case .cash, .warenkorb, .kalkulation, .nachfassen, .sendungen, .contacts:
            .handel
        case .barcode, .rechner, .farbmessung, .konfigurator, .vectorworks,
             .appLauncher, .assistant, .tools:
            .workshop
        }
    }
}

public extension WidgetBereich {
    static func gruppiert(_ kinds: [WidgetKind]) -> [(area: WidgetBereich, arten: [WidgetKind])] {
        allCases.compactMap { area in
            let arten = kinds.filter { $0.area == area }
            return arten.isEmpty ? nil : (area, arten)
        }
    }
}
