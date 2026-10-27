protocol RecordDeletePort: Sendable {
    func deleteRecord(baseID: String, table: String, recordID: String) async throws
}
