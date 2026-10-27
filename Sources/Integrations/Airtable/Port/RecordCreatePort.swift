protocol RecordCreatePort: Sendable {
    func createRecord(baseID: String, table: String, fields: [String: FieldValue]) async throws -> String
}
