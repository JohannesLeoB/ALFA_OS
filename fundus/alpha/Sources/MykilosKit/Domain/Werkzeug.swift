import Foundation

public enum WerkzeugAktion: String, Codable, CaseIterable, Sendable, Identifiable {
    case neuesProjekt
    case neuerPlan
    case mail
    case suchen

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .neuesProjekt: "Neu"
        case .neuerPlan:    "Plan"
        case .mail:         "Mail"
        case .suchen:       "Suchen"
        }
    }

    public var langerTitel: String {
        switch self {
        case .neuesProjekt: "Neues Projekt"
        case .neuerPlan:    "Neuer Plan"
        case .mail:         "Mail verfassen"
        case .suchen:       "Suchen & Springen"
        }
    }

    public var symbol: String {
        switch self {
        case .neuesProjekt: "plus.app"
        case .neuerPlan:    "pencil.and.ruler"
        case .mail:         "envelope"
        case .suchen:       "magnifyingglass"
        }
    }
}

public struct WerkzeugKonfiguration: Codable, Equatable, Sendable {
    enum CodingKeys: String, CodingKey { case isVisible = "sichtbar" }

    public private(set) var isVisible: [WerkzeugAktion]

    public init(isVisible: [WerkzeugAktion]) {
        var gesehen = Set<WerkzeugAktion>()
        self.isVisible = isVisible.filter { gesehen.insert($0).inserted }
    }

    public static let standard = WerkzeugKonfiguration(
        isVisible: [.neuesProjekt, .neuerPlan, .mail, .suchen]
    )

    public var verfuegbar: [WerkzeugAktion] {
        WerkzeugAktion.allCases.filter { isVisible.contains($0) == false }
    }

    public mutating func hinzufuegen(_ action: WerkzeugAktion) {
        guard isVisible.contains(action) == false else { return }
        isVisible.append(action)
    }

    public mutating func entfernen(_ action: WerkzeugAktion) {
        isVisible.removeAll { $0 == action }
    }

    public mutating func verschiebe(_ action: WerkzeugAktion, nachIndex target: Int) {
        guard let source = isVisible.firstIndex(of: action) else { return }
        let element = isVisible.remove(at: source)
        let begrenzt = max(0, min(target, isVisible.count))
        isVisible.insert(element, at: begrenzt)
    }
}
