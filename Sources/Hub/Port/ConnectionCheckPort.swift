public protocol ConnectionCheckPort: Sendable {
    var integration: String { get }
    func check(_ values: KeyValues) async throws -> String?
}
