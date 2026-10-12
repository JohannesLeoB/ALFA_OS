import Foundation

public enum WidgetBoardID: Hashable, Sendable, CustomStringConvertible {
    case home
    case project(String)

    public var rawValue: String {
        switch self { case .home: "home"; case let .project(p): "project_\(p)" }
    }
    public var description: String { rawValue }
}

extension WidgetBoardDefault {
    public static var homeLayout: [WidgetInstance] {
        let kinds: [WidgetKind] = [
            .projectFaves, .heuteAnstehend, .nachfassen, .focus, .recentActivity,
            .notes, .clockodo, .rechner, .barcode, .tools, .vectorworks
        ]
        return kinds.enumerated().map { i, kind in
            WidgetInstance(kind: kind, size: .standard(for: kind), position: i)
        }
    }

    public static let homeSelectableKinds: [WidgetKind] = [
        .heuteAnstehend, .nachfassen, .focus, .notes, .projectFaves, .recentActivity, .clockodo, .barcode, .rechner, .clickUpAlle, .sendungen, .tools, .aufmass, .atelier, .farbmessung, .konfigurator, .plan, .teamkalender, .vectorworks, .happaHappa, .appLauncher
    ]
}
