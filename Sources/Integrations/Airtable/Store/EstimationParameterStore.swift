import Calculation
import Core

public struct EstimationParameterStore: CarcassParameterPort {
    static let tableName = "Sch\u{00E4}tzmodell"
    static let keyField = "Schl\u{00FC}ssel"
    static let valueField = "Wert"

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

    public func load() async throws -> CarcassParameters? {
        let records = try await fetch.fetchRecords(baseID: baseID, table: table)
        var values: [String: Double] = [:]
        for record in records {
            guard let key = record.fields[Self.keyField]?.anyStringValue, key.isEmpty == false,
                  let value = Self.number(record.fields[Self.valueField]) else { continue }
            values[key] = value
        }
        guard values.isEmpty == false else { return nil }
        return CarcassParameters.from(parameters: values, fallback: .seed())
    }

    public func parameters() async -> CarcassParameters? {
        (try? await load()) ?? nil
    }

    static func number(_ value: FieldValue?) -> Double? {
        guard let value else { return nil }
        if let number = value.numberValue { return number }
        if let text = value.anyStringValue { return Double(text.replacingOccurrences(of: ",", with: ".")) }
        return nil
    }
}
