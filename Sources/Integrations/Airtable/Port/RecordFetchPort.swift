public protocol RecordFetchPort: Sendable {
    func fetchRecords(baseID: String, table: String, filterByFormula: String?) async throws -> [Record]
}

public extension RecordFetchPort {
    func fetchRecords(baseID: String, table: String) async throws -> [Record] {
        try await fetchRecords(baseID: baseID, table: table, filterByFormula: nil)
    }
}
