public protocol RecordFetchPort: Sendable {
    func fetchRecords(baseID: String, table: String, filterByFormula: String?) async throws -> [Record]
}

public extension RecordFetchPort {
    func fetchRecords(baseID: String, table: String) async throws -> [Record] {
        try await fetchRecords(baseID: baseID, table: table, filterByFormula: nil)
    }
}

public protocol CredentialsPort: Sendable {
    func load() throws -> Credentials?
}

protocol RecordCreatePort: Sendable {
    func createRecord(baseID: String, table: String, fields: [String: FieldValue]) async throws -> String
}

protocol RecordDeletePort: Sendable {
    func deleteRecord(baseID: String, table: String, recordID: String) async throws
}

protocol RecordUpdatePort: Sendable {
    func updateRecord(baseID: String, table: String, recordID: String, fields: [String: FieldValue]) async throws
}
