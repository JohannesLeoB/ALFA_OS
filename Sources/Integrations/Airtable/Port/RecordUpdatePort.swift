protocol RecordUpdatePort: Sendable {
    func updateRecord(baseID: String, table: String, recordID: String, fields: [String: FieldValue]) async throws
}
