import AlfaServices
import AppKit
import DrawingKit
import Foundation
import PDFKit

public struct TypedProject: ProjectPort {
    public init() {}

    public var origin: Origin { .local }

    public func current() -> ProjectRef? { nil }
}

public struct LocalPlaces: PlacesPort {
    public static let fontsName = "Fonts"

    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    public static var support: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Draws", isDirectory: true)
    }

    public var origin: Origin { .local }

    public var fonts: URL {
        root.appendingPathComponent(Place.source.rawValue, isDirectory: true).appendingPathComponent(Self.fontsName, isDirectory: true)
    }

    public func folder(_ place: Place, project: String?) -> URL? {
        let base = root.appendingPathComponent(place.rawValue, isDirectory: true)
        guard place != .source, let project, !ExportName.clean(project).isEmpty else { return base }
        return base.appendingPathComponent(ExportName.clean(project), isDirectory: true)
    }

    public func prepare() {
        for place in Place.allCases {
            try? FileManager.default.createDirectory(at: root.appendingPathComponent(place.rawValue, isDirectory: true),
                                                     withIntermediateDirectories: true)
        }
        try? FileManager.default.createDirectory(at: fonts, withIntermediateDirectories: true)
    }
}

public struct LocalTemplates: TemplatesPort {
    public let root: URL
    public let upload: URL?

    public init(packs: URL, fonts: URL?) {
        root = packs
        upload = fonts
    }

    public var origin: Origin { .local }

    public func packs(_ kind: PackKind) -> [PackRef] {
        let base = root.appendingPathComponent(kind.rawValue, isDirectory: true)
        let items = (try? FileManager.default.contentsOfDirectory(at: base, includingPropertiesForKeys: nil)) ?? []
        return items
            .filter { FileManager.default.fileExists(atPath: $0.appendingPathComponent(kind.file).path) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { PackRef(kind: kind, name: $0.lastPathComponent, folder: $0) }
    }

    public func fonts() -> URL? {
        upload.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
    }
}

struct FixedCredentials: ClaudeCredentialsStoring {
    let key: String
    let model: String

    func store(_ credentials: ClaudeCredentials) throws {}

    func load() throws -> ClaudeCredentials? { ClaudeCredentials(apiKey: key, model: model) }

    func clear() throws {}
}

public struct KeychainClaude: ClaudePort {
    public let credentials: any ClaudeCredentialsStoring

    public init(credentials: any ClaudeCredentialsStoring = KeychainClaudeCredentialsStore()) {
        self.credentials = credentials
    }

    public var origin: Origin { .local }
}

public struct FixedClaude: ClaudePort {
    public let credentials: any ClaudeCredentialsStoring
    public let origin: Origin

    public init(key: String, model: String, origin: Origin = .hub) {
        credentials = FixedCredentials(key: key, model: model)
        self.origin = origin
    }
}

public struct LocalDelivery: DeliveryPort {
    public init() {}

    public var origin: Origin { .local }

    @MainActor
    public func deliver(_ file: Deliverable, via handoff: Handoff) async -> Outcome {
        switch handoff {
        case .save: save(file)
        case .print: print(file)
        case .mail: mail(file)
        case .drive: .notConnected
        }
    }

    private func save(_ file: Deliverable) -> Outcome {
        guard let folder = file.folder else { return .failed("dock.reason.folder") }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent(file.name)
            try file.data.write(to: url)
            return .done(location: url.path)
        } catch {
            return .failed("\(error)")
        }
    }

    @MainActor
    private func print(_ file: Deliverable) -> Outcome {
        guard let document = PDFDocument(data: file.data),
              let operation = document.printOperation(for: NSPrintInfo.shared, scalingMode: .pageScaleToFit, autoRotate: true) else {
            return .failed("dock.reason.pdf")
        }
        return operation.run() ? .done(location: nil) : .failed("dock.reason.print")
    }

    @MainActor
    private func mail(_ file: Deliverable) -> Outcome {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(file.name)
        guard (try? file.data.write(to: url)) != nil,
              let service = NSSharingService(named: .composeEmail), service.canPerform(withItems: [url]) else {
            return .failed("dock.reason.mail")
        }
        service.subject = file.name
        service.perform(withItems: [url])
        return .done(location: nil)
    }
}

public struct PackCatalogue: CataloguePort {
    public let templates: any TemplatesPort

    public init(templates: any TemplatesPort) {
        self.templates = templates
    }

    public var origin: Origin { .local }

    public func materials() -> [Material] {
        guard let ref = templates.packs(.material).first, let loaded = try? Packs.loadMaterial(ref.folder) else { return [] }
        return loaded.pack.materials
    }
}
