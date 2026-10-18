import Foundation
import MykilosKalkulationsCore
import AlfaKit

public struct SchaetzmodellParameterProvider {
    public static let baseID = CompanySetup.valueOrEmpty("airtable.base.estimation_model")
    public static let table  = "Schätzmodell"

    private let fetcher: AirtableFetching
    public init(fetcher: AirtableFetching = AirtableClient()) { self.fetcher = fetcher }

    public func load() async -> KorpusModelParameters {
        guard let records = try? await fetcher.fetchRecords(baseID: Self.baseID, table: Self.table),
              records.isEmpty == false else { return .seed }
        var map: [String: Double] = [:]
        for record in records {
            guard let key = record["Schlüssel"]?.anyStringValue, key.isEmpty == false,
                  let value = Self.zahl(record["Wert"]) else { continue }
            map[key] = value
        }
        guard map.isEmpty == false else { return .seed }
        return KorpusModelParameters.from(parameters: map)
    }

    static func zahl(_ value: AirtableFieldValue?) -> Double? {
        guard let value else { return nil }
        if let d = value.numberValue { return d }
        if let s = value.anyStringValue { return Double(s.replacingOccurrences(of: ",", with: ".")) }
        return nil
    }
}
