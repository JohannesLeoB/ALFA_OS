import Foundation

public struct ClickUpProjektTypRoute: Codable, Hashable, Sendable, Identifiable {
    enum CodingKeys: String, CodingKey { case routeID, source = "quelle", target = "ziel", isActive = "aktiv" }

    public var id: String { routeID }
    public let routeID: String

    public let source: String
    public let target: ProjectKind
    public var isActive: Bool

    public init(routeID: String, source: String, target: ProjectKind, isActive: Bool = true) {
        self.routeID = routeID
        self.source = source
        self.target = target
        self.isActive = isActive
    }
}

public struct ClickUpProjektTypRouteRegistry: Codable, Sendable {
    public var routes: [ClickUpProjektTypRoute]

    public init(routes: [ClickUpProjektTypRoute]) {
        self.routes = routes
    }

    public func kind(fuerProjekttyp projekttyp: String?) -> ProjectKind? {
        guard let projekttyp, projekttyp.isEmpty == false else { return nil }
        return routes.first { $0.isActive && $0.source.caseInsensitiveCompare(projekttyp) == .orderedSame }?.target
    }

    public static let `default` = ClickUpProjektTypRouteRegistry(routes: [
        ClickUpProjektTypRoute(routeID: "CU_TYP_KUECHE", source: "Küche", target: .kitchen),
        ClickUpProjektTypRoute(routeID: "CU_TYP_LICHT", source: "Licht", target: .lighting),
        ClickUpProjektTypRoute(routeID: "CU_TYP_NACHTRAG", source: "Nachtrag", target: .addendum),
        ClickUpProjektTypRoute(routeID: "CU_TYP_LEAD", source: "Lead", target: .lead),
        ClickUpProjektTypRoute(routeID: "CU_TYP_ANGEBOT", source: "Angebot", target: .quote),
        ClickUpProjektTypRoute(routeID: "CU_TYP_INTERN", source: "Intern", target: .studioInternal)
    ])
}
