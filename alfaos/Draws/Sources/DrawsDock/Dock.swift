import DrawingKit
import Foundation

public enum PortID: String, CaseIterable, Sendable {
    case project
    case places
    case files
    case templates
    case claude
    case delivery
    case catalogue

    public var key: String { "dock.port." + rawValue }
}

public enum PortState: Sendable, Equatable {
    case connected
    case local
    case missing(reason: String)

    public var key: String {
        switch self {
        case .connected: "dock.state.connected"
        case .local: "dock.state.local"
        case .missing: "dock.state.missing"
        }
    }

    public var reason: String? {
        if case .missing(let reason) = self { reason } else { nil }
    }
}

public struct Check: Sendable, Equatable {
    public var port: PortID
    public var state: PortState

    public init(port: PortID, state: PortState) {
        self.port = port
        self.state = state
    }
}

public struct Dock: Sendable {
    public var project: any ProjectPort
    public var places: any PlacesPort
    public var files: any FilesPort
    public var templates: any TemplatesPort
    public var claude: any ClaudePort
    public var delivery: any DeliveryPort
    public var catalogue: any CataloguePort

    public init(project: any ProjectPort, places: any PlacesPort, files: any FilesPort, templates: any TemplatesPort, claude: any ClaudePort,
                delivery: any DeliveryPort, catalogue: any CataloguePort) {
        self.project = project
        self.places = places
        self.files = files
        self.templates = templates
        self.claude = claude
        self.delivery = delivery
        self.catalogue = catalogue
    }

    public static func local(packs: URL, places: LocalPlaces, claude: any ClaudePort = KeychainClaude()) -> Dock {
        let templates = LocalTemplates(packs: packs, fonts: places.fonts)
        let files = LocalFiles(places: places)
        return Dock(project: TypedProject(), places: places, files: files, templates: templates, claude: claude,
                    delivery: LocalDelivery(files: files), catalogue: PackCatalogue(templates: templates))
    }

    public func check() -> [Check] {
        let rows: [(PortID, Origin, String?)] = [
            (.project, project.origin, project.origin == .hub && project.current() == nil ? "dock.reason.project" : nil),
            (.places, places.origin, placesLack()),
            (.files, files.origin, files.origin == .local ? placesLack() : nil),
            (.templates, templates.origin, PackKind.allCases.contains { templates.packs($0).isEmpty } ? "dock.reason.packs" : nil),
            (.claude, claude.origin, claudeLack()),
            (.delivery, delivery.origin, nil),
            (.catalogue, catalogue.origin, catalogue.materials().isEmpty ? "dock.reason.catalogue" : nil)
        ]
        return rows.map { port, origin, lack in
            Check(port: port, state: lack.map { PortState.missing(reason: $0) } ?? (origin == .hub ? .connected : .local))
        }
    }

    public func destination(_ place: Place, project number: String?) -> URL? {
        guard let url = places.folder(place, project: number) else { return nil }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    public func stateURL(_ spot: Spot) -> URL? {
        places.folder(.state, project: spot.project).map { spot.path.reduce($0) { $0.appendingPathComponent($1) } }
    }

    public func loadCI() throws -> Loaded<CIPack>? {
        try templates.packs(.ci).first.map { try Packs.loadCI($0.folder) }
    }

    public func loadTemplate() throws -> Loaded<TemplatePack>? {
        try templates.packs(.template).first.map(loadTemplate)
    }

    public func loadTemplate(_ ref: PackRef) throws -> Loaded<TemplatePack> {
        try Packs.loadTemplate(ref.folder, also: templates.packs(.ci).map(\.folder))
    }

    public func loadCI(named name: String) throws -> Loaded<CIPack>? {
        try templates.packs(.ci).first { $0.name == name }.map { try Packs.loadCI($0.folder) }
    }

    public func loadMaterial() throws -> Loaded<MaterialPack>? {
        try templates.packs(.material).first.map { try Packs.loadMaterial($0.folder) }
    }

    private func placesLack() -> String? {
        for place in Place.allCases {
            guard let url = places.folder(place, project: nil) else { return "dock.reason.place" }
            if !FileManager.default.fileExists(atPath: url.path) { return "dock.reason.folder" }
        }
        return nil
    }

    private func claudeLack() -> String? {
        switch claude.readiness() {
        case .ready: nil
        case .noKey: "dock.reason.key"
        case .noModel: "dock.reason.model"
        }
    }
}
