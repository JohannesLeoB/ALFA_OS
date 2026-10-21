import AlfaServices
import DrawingKit
import Foundation

public enum Origin: Sendable, Equatable {
    case hub
    case local
}

public protocol Linked: Sendable {
    var origin: Origin { get }
}

public struct ProjectRef: Sendable, Equatable {
    public var projectNumber: String
    public var fields: [String: String]

    public init(projectNumber: String, fields: [String: String]) {
        self.projectNumber = projectNumber
        self.fields = fields
    }
}

public protocol ProjectPort: Linked {
    func current() -> ProjectRef?
}

public enum Place: String, CaseIterable, Sendable {
    case state
    case presentation
    case trade
    case source
}

public protocol PlacesPort: Linked {
    func folder(_ place: Place, project: String?) -> URL?
}

public struct FileFolder: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public struct FileEntry: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let mimeType: String
    public let isFolder: Bool

    public init(id: String, name: String, mimeType: String, isFolder: Bool = false) {
        self.id = id
        self.name = name
        self.mimeType = mimeType
        self.isFolder = isFolder
    }
}

public protocol FilesPort: Linked {
    func projectFolders() async throws -> [FileFolder]
    func files(in folderID: String) async throws -> [FileEntry]
    func read(_ fileID: String) async throws -> Data
    func put(name: String, mimeType: String, data: Data, into folderID: String) async throws -> FileEntry
}

public enum PackKind: String, CaseIterable, Sendable {
    case ci
    case template
    case material

    public var file: String { rawValue + ".json" }
}

public struct PackRef: Sendable, Equatable, Identifiable {
    public var kind: PackKind
    public var name: String
    public var folder: URL

    public var id: String { kind.rawValue + "/" + name }

    public init(kind: PackKind, name: String, folder: URL) {
        self.kind = kind
        self.name = name
        self.folder = folder
    }
}

public protocol TemplatesPort: Linked {
    func packs(_ kind: PackKind) -> [PackRef]
    func fonts() -> URL?
}

public enum Readiness: Sendable, Equatable {
    case ready(model: String)
    case noKey
    case noModel
}

public protocol ClaudePort: Linked {
    var credentials: any ClaudeCredentialsStoring { get }
}

extension ClaudePort {
    public func readiness() -> Readiness {
        let stored = try? credentials.load()
        guard let key = stored?.apiKey, !key.isEmpty else { return .noKey }
        let model = stored?.model.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return model.isEmpty ? .noModel : .ready(model: model)
    }
}

public enum Handoff: String, CaseIterable, Sendable {
    case save
    case print
    case mail
    case drive
}

public struct Deliverable: Sendable, Equatable {
    public var name: String
    public var mimeType: String
    public var data: Data
    public var folder: URL?
    public var place: Place

    public init(name: String, mimeType: String, data: Data, folder: URL? = nil, place: Place = .presentation) {
        self.name = name
        self.mimeType = mimeType
        self.data = data
        self.folder = folder
        self.place = place
    }
}

public enum Outcome: Sendable, Equatable {
    case done(location: String?)
    case failed(String)
    case notConnected
}

public protocol DeliveryPort: Linked {
    @MainActor func deliver(_ file: Deliverable, via handoff: Handoff) async -> Outcome
}

public protocol CataloguePort: Linked {
    func materials() -> [Material]
}
