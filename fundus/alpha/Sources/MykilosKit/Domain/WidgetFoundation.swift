import Foundation

public enum WidgetKind: String, Codable, CaseIterable, Sendable {
    case drive
    case tasks
    case contacts
    case cash
    case calendar
    case notes
    case assistant

    case focus
    case projectFaves
    case clockodo
    case recentActivity
    case kalkulation
    case warenkorb
    case barcode
    case rechner
    case clickUpAlle
    case heuteAnstehend
    case sendungen
    case aufmass
    case teamkalender
    case maps
    case vectorworks
    case happaHappa
    case nachfassen

    case farbmessung
    case atelier
    case konfigurator
    case kreativCanvas
    case imFluss
    case plan
    case appLauncher

    case heroBild
    case phasenfluss
    case tools
}

public enum WidgetSize: String, Codable, Sendable {
    case small
    case medium
    case wide
    case full
    case g1x1, g1x2, g2x1, g2x2, g2x3, g3x1, g3x2

    public var columns: Int {
        switch self {
        case .small, .medium, .g1x1, .g1x2: return 1
        case .wide, .g2x1, .g2x2, .g2x3:     return 2
        case .full, .g3x1, .g3x2:            return 3
        }
    }

    public var rowItems: Int {
        switch self {
        case .small, .g1x1, .g2x1, .g3x1:                return 1
        case .medium, .wide, .full, .g1x2, .g2x2, .g3x2: return 2
        case .g2x3:                                      return 3
        }
    }

    public static func fuer(columns: Int, rowItems: Int) -> WidgetSize {
        switch (max(1, min(3, columns)), max(1, min(3, rowItems))) {
        case (1, 1): return .g1x1
        case (1, _): return .g1x2
        case (2, 1): return .g2x1
        case (2, 2): return .g2x2
        case (2, 3): return .g2x3
        case (3, 1): return .g3x1
        default:     return .g3x2
        }
    }

    public var columnSpan: Int { columns }
    public var hoehenFaktor: Double { Double(rowItems) }

    public static func standard(for kind: WidgetKind) -> WidgetSize {
        switch kind {
        case .heroBild:    return .g1x2
        case .phasenfluss: return .g2x1
        case .tools:   return .g2x1
        case .aufmass, .barcode, .konfigurator, .atelier, .plan, .appLauncher,
             .happaHappa, .kreativCanvas:
            return .g1x1
        case .notes, .rechner, .farbmessung:
            return .g1x2
        case .vectorworks, .imFluss, .sendungen, .clockodo, .maps:
            return .g2x1
        case .assistant:
            return .g2x3
        case .clickUpAlle, .projectFaves, .teamkalender:
            return .g3x2
        default:
            return .g2x2
        }
    }
}

public struct WidgetInstance: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var kind: WidgetKind
    public var size: WidgetSize
    public var position: Int
    public var isVisible: Bool
    public var isPinned: Bool

    public init(id: UUID = UUID(), kind: WidgetKind, size: WidgetSize = .medium,
                position: Int, isVisible: Bool = true, isPinned: Bool = false) {
        self.id = id; self.kind = kind; self.size = size
        self.position = position; self.isVisible = isVisible; self.isPinned = isPinned
    }
}

public enum WidgetBoardDefault {
    public static var canonicalLayout: [WidgetInstance] {
        let kinds: [WidgetKind] = [.heroBild, .phasenfluss, .contacts,
                                   .tasks, .calendar, .cash, .notes, .warenkorb, .drive, .assistant]
        return kinds.enumerated().map { i, kind in
            WidgetInstance(kind: kind, size: .standard(for: kind), position: i)
        }
    }

    public static func layout(for kind: ProjectKind) -> [WidgetInstance] {
        canonicalLayout
    }
}
