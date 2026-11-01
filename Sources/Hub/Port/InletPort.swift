import Foundation

protocol InletPort: Sendable {
    func load() throws -> [Inlet]
    func save(_ inlet: Inlet, slots: [String]?) throws
    func loadReports() throws -> [Inlet.ID: [ReportEntry]]
    func append(_ entry: ReportEntry, limit: Int) throws
    func slots(of inlet: Inlet.ID) throws -> [String]
    func delete(_ inlet: Inlet.ID) throws
}

extension InletPort {
    func save(_ inlet: Inlet) throws {
        try save(inlet, slots: nil)
    }
}

protocol FolderWatchPort: Sendable {
    func start(
        _ key: String,
        port: any ChangePort,
        isTransient: @escaping @Sendable (any Error) -> Bool,
        fire: @escaping @Sendable () async -> Void,
        unavailable: @escaping @Sendable () -> Void
    )
    func stop(_ key: String)
}

public protocol SettingPort: Sendable {
    func all() throws -> [String: Data]
    func value<V: Decodable>(_ key: String, as type: V.Type) throws -> V?
    func store<V: Encodable>(_ value: V, forKey key: String) throws
    func remove(key: String) throws
    func remove(withPrefix prefix: String) throws
}

public protocol TemplatePort: Sendable {
    var templates: [TemplateFile] { get }
    func text(_ template: TemplateFile) -> String?
    func add(from source: URL) throws -> TemplateFile
    func remove(_ template: TemplateFile) throws
}

public protocol IntegrationCatalogPort: Sendable {
    var entries: [IntegrationInfo] { get }
    func info(_ id: String) -> IntegrationInfo?
    func info(forProvider provider: String) -> IntegrationInfo?
}
