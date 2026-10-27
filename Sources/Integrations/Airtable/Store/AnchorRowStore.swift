import Calculation
import Core

public struct AnchorRowStore: AnchorRowsPort {
    static let tableName = "Preisanker"

    private let fetch: any RecordFetchPort
    private let baseID: String
    private let table: String

    public init(fetch: any RecordFetchPort,
                baseID: String = CompanyValues.valueOrEmpty("airtable.base.estimation_model"),
                table: String? = nil) {
        self.fetch = fetch
        self.baseID = baseID
        self.table = table ?? Self.tableName
    }

    public func fetchAnchorRows() async throws -> [[String: String]] {
        try await fetch.fetchRecords(baseID: baseID, table: table).map { record in
            record.fields.mapValues { $0.anyStringValue ?? $0.firstArrayValue ?? "" }
        }
    }
}
