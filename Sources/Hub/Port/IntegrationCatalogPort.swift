public protocol IntegrationCatalogPort: Sendable {
    var entries: [IntegrationInfo] { get }
    func info(_ id: String) -> IntegrationInfo?
    func info(forProvider provider: String) -> IntegrationInfo?
}
