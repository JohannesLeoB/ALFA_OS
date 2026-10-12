import Foundation

public enum MailAnhangMarker: String, CaseIterable, Codable, Sendable, Identifiable {
    case auftragsbestaetigung
    case rechnung
    case zeichnung
    case angebotAusgehend

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .auftragsbestaetigung: return "AB"
        case .rechnung: return "Rechnung"
        case .zeichnung: return "Zeichnung"
        case .angebotAusgehend: return "Angebot (ausgehend)"
        }
    }
}

public struct MailMarkerRoute: Codable, Hashable, Sendable, Identifiable {
    enum CodingKeys: String, CodingKey { case routeID, marker, target = "ziel", isActive = "aktiv" }

    public var id: String { routeID }

    public let routeID: String
    public let marker: MailAnhangMarker

    public let target: OrdnerSlot

    public var isActive: Bool

    public init(routeID: String, marker: MailAnhangMarker, target: OrdnerSlot, isActive: Bool = true) {
        self.routeID = routeID
        self.marker = marker
        self.target = target
        self.isActive = isActive
    }
}

public struct MailMarkerRouteRegistry: Codable, Sendable {
    public var routes: [MailMarkerRoute]

    public init(routes: [MailMarkerRoute]) {
        self.routes = routes
    }

    public var aktiveRoutes: [MailMarkerRoute] {
        routes.filter(\.isActive)
    }

    public func route(fuer marker: MailAnhangMarker) -> MailMarkerRoute? {
        routes.first { $0.isActive && $0.marker == marker }
    }

    public static let `default` = MailMarkerRouteRegistry(routes: [
        MailMarkerRoute(routeID: "MAIL_MARKER_AB", marker: .auftragsbestaetigung, target: .angeboteEingehend),
        MailMarkerRoute(routeID: "MAIL_MARKER_RECHNUNG", marker: .rechnung, target: .angeboteEingehend),
        MailMarkerRoute(routeID: "MAIL_MARKER_ZEICHNUNG", marker: .zeichnung, target: .cad),
        MailMarkerRoute(routeID: "MAIL_MARKER_ANGEBOT_AUSGEHEND", marker: .angebotAusgehend, target: .angeboteAusgehend)
    ])
}
