public protocol AnchorRowsPort: Sendable {
    func fetchAnchorRows() async throws -> [[String: String]]
}
