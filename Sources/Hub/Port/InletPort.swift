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
